import Flutter
import UIKit
import Braintree
import PassKit

public class FlutterBraintreeCustomPlugin: BaseFlutterBraintreePlugin, FlutterPlugin, PKPaymentAuthorizationViewControllerDelegate {

    var channel: FlutterMethodChannel?

    private var eventSink: FlutterEventSink?
    private var venmoCancelledObserver: NSObjectProtocol?

    var applePayCompletion: FlutterResult?
    var braintreeClient: BTAPIClient?
    var applePayClient: BTApplePayClient?
    var paymentRequest: PKPaymentRequest?
    var threeDSClient: BTThreeDSecureClient?


    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "flutter_braintree.custom",
            binaryMessenger: registrar.messenger()
        )

        let instance = FlutterBraintreeCustomPlugin()
        instance.channel = channel

        registrar.addMethodCallDelegate(instance, channel: channel)

        // Forward VenmoCancelled notifications to Dart
        instance.venmoCancelledObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("VenmoCancelled"),
            object: nil,
            queue: OperationQueue.main
        ) {
            [weak instance] _ in
            instance?.channel?.invokeMethod("onVenmoCancelled", arguments: nil)
        }

        // NEW: Reset internal lock to avoid "already running"
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("VenmoReset"),
            object: nil,
            queue: OperationQueue.main
        ) {
            [weak instance] _ in
            instance?.isHandlingResult = false
        }
    }

    deinit {
        if let observer = venmoCancelledObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard !isHandlingResult else {
            returnAlreadyOpenError(result: result)
            return
        }

        isHandlingResult = true

        guard let authorization = getAuthorization(call: call) else {
            returnAuthorizationMissingError(result: result)
            isHandlingResult = false
            return
        }

        let client = BTAPIClient(authorization: authorization)
        braintreeClient = client

        switch call.method {

        case "collectDeviceData":
            BraintreeDeviceCollector.collectDeviceData(
                tokenizationKey: authorization,
                result: result
            )
            self.isHandlingResult = false
            return

        case "startCardPayment":
            handleStartCardPayment(call, client: client, result: result)

        case "tokenizeApplePay":
            handleApplePay(call, client: client, result: result)

        case "startVenmo":
            handleVenmo(call, client: client, result: result)

        case "startPayPal":
            handlePayPal(call, client: client, result: result)

        default:
            result(FlutterMethodNotImplemented)
            self.isHandlingResult = false
        }
    }

    // MARK: - PAYPAL (Checkout only)

    private func handlePayPal(_ call: FlutterMethodCall, client: BTAPIClient, result: @escaping FlutterResult) {

        print("🟦 Starting PayPal Checkout")

        guard let args = call.arguments as? [String: Any],
        let amount = args["amount"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing amount", details: nil))
            self.isHandlingResult = false
            return
        }

        let currencyCode = (args["currencyCode"] as? String) ?? "USD"

        let request = BTPayPalCheckoutRequest(
            amount: amount,
            intent: .sale,
            currencyCode: currencyCode
        )

        let paypalClient = BTPayPalClient(authorization: client.authorization.originalValue)

        paypalClient.tokenize(request) {
            account, error in
            defer {
                self.isHandlingResult = false
            }

            // --------------------
            // CANCELLATION CHECKS
            // --------------------

            // 1️⃣ Buyer tapped Cancel → (account=nil, error=nil)
            if account == nil && error == nil {
                print("⚠️ PayPal cancelled — no account")
                result(nil)
                return
            }

            // 2️⃣ SDK returns a cancel error string
            if let err = error as NSError? {
                if err.localizedDescription.lowercased().contains("canceled") || err.localizedDescription.lowercased().contains("cancelled") {
                    print("⚠️ PayPal cancelled — browser/app closed")
                    result(nil)
                    return
                }

                print("❌ PayPal ERROR: \(err.localizedDescription)")
                self.returnBraintreeError(result: result, error: err)
                return
            }

            // --------------------
            // SUCCESS CASE
            // --------------------
            guard let account = account else {
                print("⚠️ Unknown PayPal outcome, returning NULL")
                result(nil)
                return
            }

            print("🎉 PayPal success: \(account.nonce)")

            let collector = BTDataCollector(authorization: client.authorization.originalValue)
            collector.collectDeviceData {
                deviceData, _ in

                let dict: [String: Any] = [
                    "nonce": account.nonce,
                    "email": account.email ?? "",
                    "payerId": account.payerID ?? "",
                    "deviceData": deviceData ?? ""
                ]

                print("📤 Returning PayPal result")
                result(dict)
            }
        }
    }

    // MARK: - VENMO

    private func handleVenmo(_ call: FlutterMethodCall, client: BTAPIClient, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
        let usage = args["usage"] as? String,
        let amount = args["amount"] as? String,
        let universalLinkStr = args["appLinkUrl"] as? String,
        let universalReturnURL = URL(string: universalLinkStr) else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing Venmo params (amount, usage, universalLink)",
                details: nil
            ))
            self.isHandlingResult = false
            return
        }

        let venmoClient = BTVenmoClient(
            authorization: client.authorization.originalValue,
            universalLink: universalReturnURL
        )


        let request = BTVenmoRequest(
            paymentMethodUsage: usage == "MULTI_USE" ? .multiUse: .singleUse,
            totalAmount: amount,
        )

        venmoClient.tokenize(request) {
            venmoAccount, error in

            if let error = error {
                self.returnBraintreeError(result: result, error: error)
                self.isHandlingResult = false
                return
            }

            guard let account = venmoAccount else {
                result(nil)
                self.isHandlingResult = false
                return
            }

            // Now collect device data
            let dataCollector = BTDataCollector(
                authorization: client.authorization.originalValue
            )
            dataCollector.collectDeviceData {
                deviceData, error in

                let response: [String: Any] = [
                    "nonce": account.nonce,
                    "username": account.username ?? "",
                    "deviceData": deviceData ?? ""
                ]

                result(response)
                self.isHandlingResult = false
            }
        }
    }


    // MARK: - CREDIT CARD

    private func handleStartCardPayment(_ call: FlutterMethodCall, client: BTAPIClient, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let require3DS = args?["require3DS"] as? Bool ?? true
        let forceChallenge = args?["forceChallenge"] as? Bool ?? false

        print("📥 [3DS] Received startCardPayment call")
        guard let cardInfo = dict(for: "request", in: call),
        let amount = cardInfo["amount"] as? String else {
            print("❌ [3DS] Missing card amount")
            result(FlutterError(code: "INVALID_REQUEST", message: "Missing card amount", details: nil))
            self.isHandlingResult = false
            return
        }

        print("💳 [3DS] Card Info received: \(cardInfo)")
        print("💳 [3DS] Card Token: \(client.authorization.originalValue)")

        // Build card
        guard let number = cardInfo["cardNumber"] as? String,
        let month = cardInfo["expirationMonth"] as? String,
        let year = cardInfo["expirationYear"] as? String,
        let cvv = cardInfo["cvv"] as? String else {
            result(FlutterError(code: "INVALID_CARD", message: "Missing card fields", details: nil))
            self.isHandlingResult = false
            return
        }

        let card = BTCard(
            number: number,
            expirationMonth: month,
            expirationYear: year,
            cvv: cvv,
            postalCode: cardInfo["postalCode"] as? String,
            streetAddress: cardInfo["streetAddress"] as? String
        )

        print("🔧 [3DS] Starting card tokenization…")

        let cardClient = BTCardClient(authorization: client.authorization.originalValue)

        cardClient.tokenize(card) {
            nonce, error in

            if let error = error {
                print("❌ [3DS] Tokenization Error: \(error.localizedDescription)")
                self.returnBraintreeError(result: result, error: error)
                self.isHandlingResult = false
                return
            }

            guard let nonce = nonce else {
                print("❌ [3DS] Tokenization returned NO nonce")
                result(FlutterError(code: "NO_NONCE", message: "No nonce returned", details: nil))
                self.isHandlingResult = false
                return
            }
            
            print("✅ [3DS] Tokenization success → nonce: \(nonce.nonce)")
            
            if !require3DS {

                print("⚠️ [3DS] require3DS = false → skipping 3DS flow")

                let dataCollector = BTDataCollector(authorization: client.authorization.originalValue)

                dataCollector.collectDeviceData { deviceData, _ in

                    var response: [String: Any] = [
                        "nonce": nonce.nonce,
                        "type": nonce.type,
                        "description": nonce.description,
                        "liabilityShifted": false,
                        "liabilityShiftPossible": false
                    ]

                    if let deviceData = deviceData {
                        response["deviceData"] = deviceData
                    }

                    print("📤 Returning NON-3DS nonce to Flutter")

                    result(response)

                    self.isHandlingResult = false
                }

                return
            }

            // Build 3DS request
            let threeDSRequest = BTThreeDSecureRequest(
                amount: amount,
                nonce: nonce.nonce,
                challengeRequested: forceChallenge
            )
            
            threeDSRequest.threeDSecureRequestDelegate = self

            print("🛡️ [3DS] Built BTThreeDSecureRequest")
            print("   - Amount: \(amount)")
            print("   - Nonce: \(nonce.nonce)")

            // Strongly retain 3DS client
            self.threeDSClient = BTThreeDSecureClient(
                authorization: client.authorization.originalValue
            )

            print("🛑 [3DS] Created ThreeDSClient → retained strongly")

            self.threeDSClient?.start(threeDSRequest) {
                threeDSResult, error in

                if let error = error {

                    // 1) Direct cast to enum (works if the SDK returns the Swift enum).
                    if let tdsError = error as? BTThreeDSecureError, tdsError == .canceled {
                        print("🚫 [3DS] User cancelled challenge (BTThreeDSecureError.canceled). Returning nil to Flutter.")
                        result(nil)                       // signal cancellation to Flutter
                        self.isHandlingResult = false
                        self.threeDSClient = nil
                        return
                    }

                    // 2) Fallback to NSError domain + code (covers bridged NSError cases)
                    let nsError = error as NSError
                    if nsError.domain == BTThreeDSecureError.errorDomain && nsError.code == BTThreeDSecureError.canceled.errorCode {
                        print("🚫 [3DS] User cancelled challenge (NSError bridged). Returning nil to Flutter.")
                        result(nil)
                        self.isHandlingResult = false
                        self.threeDSClient = nil
                        return
                    }

                    // 3) Not a cancellation -> real error
                    print("❌ [3DS] startPaymentFlow ERROR: \(error.localizedDescription)")
                    self.returnBraintreeError(result: result, error: error)
                    self.isHandlingResult = false
                    self.threeDSClient = nil
                    return
                }

                print("🔄 [3DS] startPaymentFlow completed, analyzing result…")

                guard let verifiedCard = threeDSResult?.tokenizedCard else {
                    print("❌ [3DS] Verified card missing (3DS failed?)")
                    result(FlutterError(code: "3DS_FAIL", message: "Missing verified card", details: nil))
                    self.isHandlingResult = false
                    self.threeDSClient = nil
                    return
                }

                print("🎉 [3DS] 3DS Authentication SUCCESS")
                print("   - Verified nonce: \(verifiedCard.nonce)")
                print("   - Type: \(verifiedCard.type)")
                print("   - Description: \(verifiedCard.description)")
                print("   - Liability Shifted: \(verifiedCard.threeDSecureInfo.liabilityShifted)")
                print("   - Liability Shift Possible: \(verifiedCard.threeDSecureInfo.liabilityShiftPossible)")

                // Device data collection
                print("📡 [3DS] Collecting device data…")

                let dataCollector = BTDataCollector(authorization: client.authorization.originalValue)
                dataCollector.collectDeviceData {
                    deviceData, _ in

                    print("📦 [3DS] Device data collected")

                    var response: [String: Any] = [
                        "nonce": verifiedCard.nonce,
                        "type": verifiedCard.type,
                        "description": verifiedCard.description,
                        "liabilityShifted": verifiedCard.threeDSecureInfo.liabilityShifted,
                        "liabilityShiftPossible": verifiedCard.threeDSecureInfo.liabilityShiftPossible
                    ]

                    if let deviceData = deviceData {
                        print("📝 [3DS] Adding deviceData to response")
                        response["deviceData"] = deviceData
                    }

                    print("📤 [3DS] Sending final response back to Flutter")
                    result(response)

                    self.isHandlingResult = false
                    self.threeDSClient = nil // cleanup
                }
            }

            print("🚀 [3DS] Starting 3DS2 flow…")

        }
    }


    // MARK: - APPLE PAY

    private func handleApplePay(_ call: FlutterMethodCall, client: BTAPIClient, result: @escaping FlutterResult) {

        applePayCompletion = result
        applePayClient = BTApplePayClient(authorization: client.authorization.originalValue)

        print("🍏 Starting Apple Pay flow")

        // Read "request" dictionary from Flutter
        guard let args = call.arguments as? [String: Any],
        let info = args["request"] as? [String: Any],
        let amount = info["amount"] as? String,
        let label = info["label"] as? String,
        let company = info["company"] as? String else {
            print("❌ Missing Apple Pay arguments")
            self.isHandlingResult = false
            result(FlutterError(code: "MISSING_ARGS", message: "Invalid Apple Pay params", details: nil))
            return
        }

        let merchantId = info["merchantIdentifier"] as? String
        let countryCode = info["countryCode"] as? String ?? "US"
        let currencyCode = info["currencyCode"] as? String ?? "USD"

        // Build PKPaymentRequest using Braintree's helper
        applePayClient?.makePaymentRequest {
            (paymentRequest, error) in

            if let error = error {
                print("❌ makePaymentRequest error: \(error.localizedDescription)")
                self.returnBraintreeError(result: result, error: error)
                self.isHandlingResult = false
                return
            }

            guard let request = paymentRequest else {
                print("❌ PaymentRequest is nil")
                self.isHandlingResult = false
                result(FlutterError(code: "APPLE_PAY_FAIL", message: "Cannot create Apple Pay request", details: nil))
                return
            }

            print("✅ PaymentRequest created")

            // Configure Apple Pay request
            if let merchantId = merchantId {
                request.merchantIdentifier = merchantId
            }

            request.countryCode = countryCode
            request.currencyCode = currencyCode
            request.merchantCapabilities = [.capability3DS, .capabilityDebit, .capabilityCredit]

            // Summary items — EXACTLY how Apple requires:
            request.paymentSummaryItems = [
                PKPaymentSummaryItem(label: label, amount: NSDecimalNumber(string: amount)),
                PKPaymentSummaryItem(label: company, amount: NSDecimalNumber(string: amount))
            ]

            print("Can make payments:",
                PKPaymentAuthorizationViewController.canMakePayments())

            print("Can make payments with networks:",
                PKPaymentAuthorizationViewController.canMakePayments(
                    usingNetworks: [.visa, .masterCard, .amex, .discover]
                ))

            // Create Apple Pay View
            guard let vc = PKPaymentAuthorizationViewController(paymentRequest: request) else {
                print("❌ Failed to create PKPaymentAuthorizationViewController")
                self.isHandlingResult = false
                result(FlutterError(code: "APPLE_PAY_VIEW_FAIL", message: "Cannot present Apple Pay sheet", details: nil))
                return
            }

            vc.delegate = self

            // Present
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.windows.first(where: {
                $0.isKeyWindow
            })?.rootViewController {

                print("📱 Presenting Apple Pay sheet")
                root.present(vc, animated: true)
            } else {
                print("❌ Could not find root VC")
                self.isHandlingResult = false
                result(FlutterError(code: "NO_ROOT_VC", message: "Cannot present Apple Pay", details: nil))
            }
        }
    }


    // MARK: - APPLE PAY DELEGATES

    public func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController,
    didAuthorizePayment payment: PKPayment,
    handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {

        print("🍏 Apple Pay authorized, tokenizing…")

        applePayClient?.tokenize(payment) {
            (nonce, error) in

            if let error = error {
                print("❌ Tokenization error: \(error.localizedDescription)")
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                self.returnBraintreeError(result: self.applePayCompletion ?? {
                    _ in
                }, error: error)
                self.isHandlingResult = false
                return
            }

            guard let nonce = nonce else {
                print("❌ No nonce returned from Apple Pay")
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                self.applePayCompletion? (nil)
                self.isHandlingResult = false
                return
            }

            // Collect device data (fraud)
            print("📡 Collecting device data…")
            let dataCollector = BTDataCollector(authorization: self.braintreeClient!.authorization.originalValue)

            dataCollector.collectDeviceData {
                deviceData, error in

                if let error = error {
                    print("⚠️ Device data collection failed: \(error.localizedDescription)")
                }

                let dict: [String: Any] = [
                    "nonce": nonce.nonce,
                    "type": nonce.type,
                    "description": nonce.description,
                    "deviceData": deviceData ?? ""
                ]

                print("📤 Returning Apple Pay nonce to Flutter")
                self.applePayCompletion? (dict)

                completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
                self.isHandlingResult = false
            }
        }
    }

    public func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true) {
            if self.isHandlingResult {
                print("🟡 User cancelled Apple Pay – returning NULL")
                self.applePayCompletion? (nil)  // means CANCEL
                self.isHandlingResult = false
            }
        }
    }


    // MARK: - COMMON
    private func handleResult(nonce: BTPaymentMethodNonce?, error: Error?, flutterResult: FlutterResult) {
        if let error = error {
            returnBraintreeError(result: flutterResult, error: error)
        } else if let nonce = nonce {
            flutterResult(buildPaymentNonceDict(nonce: nonce))
        } else {
            flutterResult(nil)
        }
    }

}

extension FlutterBraintreeCustomPlugin: BTThreeDSecureRequestDelegate {

    public func onLookupComplete(_ request: BTThreeDSecureRequest,
    lookupResult: BTThreeDSecureResult,
    next: @escaping () -> Void) {

        guard let lookup = lookupResult.lookup else {
            print("❗ lookupResult.lookup is NIL → likely frictionless flow")
            next()
            return
        }

        print("   • requiresUserAuthentication: \(lookup.requiresUserAuthentication)")
        print("   • isThreeDSecureVersion2: \(lookup.isThreeDSecureVersion2)")
        print("   • threeDSecureVersion: \(lookup.threeDSecureVersion ?? "nil")")
        print("   • transactionID: \(lookup.transactionID ?? "nil")")
        print("   • acsURL: \(lookup.acsURL?.absoluteString ?? "nil")")
        print("   • termURL: \(lookup.termURL?.absoluteString ?? "nil")")
        print("   • paReq present: \(lookup.paReq != nil)")
        print("   • md: \(lookup.md ?? "nil")")


        next()
    }
}
