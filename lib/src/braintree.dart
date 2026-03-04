import 'package:flutter/services.dart';
import 'dart:async';

/// A Flutter wrapper around the native Braintree SDKs.
///
/// This class exposes static methods to initiate various
/// payment flows including:
/// - Credit Card (with optional 3D Secure)
/// - PayPal
/// - Google Pay
/// - Apple Pay
/// - Venmo
/// - Device data collection
///
/// All methods communicate with the native Android and iOS SDKs
/// via platform channels.
///
/// ⚠️ The returned nonce must be verified and used on your backend
/// to securely create transactions.

class Braintree {
  static const MethodChannel _kChannel = MethodChannel('flutter_braintree.custom');

  const Braintree._();

  /// Starts a credit/debit card payment using the native Braintree SDK.
  ///
  /// The [authorization] must be either:
  /// - A valid **client token** generated from your backend, or
  /// - A valid **tokenization key** from your Braintree dashboard.
  ///
  /// The card details are securely passed to the native SDK for tokenization.
  ///
  /// Returns:
  /// - A `Map<String, dynamic>` containing:
  ///     - `nonce` → The payment method nonce.
  ///     - `deviceData` → Fraud detection device data (if available).
  ///     - `liabilityShifted` → Whether 3D Secure liability shift occurred.
  ///     - `liabilityShiftPossible` → Whether liability shift was possible.
  /// - A map containing `error` if a platform error occurs.
  /// - `null` if the user cancels the payment flow.
  ///
  /// ⚠️ You must send the returned nonce to your backend to create a transaction.
  /// Never complete transactions directly from the client.

  static Future<Map<String, dynamic>?> startCardPayment({
    required String authorization,
    required String cardNumber,
    required String expirationMonth,
    required String expirationYear,
    required String cvv,
    required String amount,
  }) async {
    try {
      final result = await _kChannel.invokeMethod('startCardPayment', {
        'authorization': authorization,
        'request': {
          'cardNumber': cardNumber,
          'expirationMonth': expirationMonth,
          'expirationYear': expirationYear,
          'cvv': cvv,
          'amount': amount,
        },
      });

      if (result != null && result is Map) {
        return Map<String, dynamic>.from(result);
      }
    } on PlatformException catch (e) {
      return {'error': e.message};
    }
    return null;
  }

  /// Starts a credit card payment with optional billing address information.
  ///
  /// The [authorization] must be a valid client token or tokenization key.
  ///
  /// Billing fields such as [streetAddress] and [postalCode] are optional
  /// but may improve fraud detection and 3D Secure verification.
  ///
  /// Returns:
  /// - A `Map<String, dynamic>` containing:
  ///     - `nonce` → The payment method nonce.
  ///     - `deviceData` → Fraud detection device data (if available).
  ///     - `liabilityShifted` → Whether 3D Secure liability shift occurred.
  ///     - `liabilityShiftPossible` → Whether liability shift was possible.
  /// - A map containing `error` if a platform error occurs.
  /// - `null` if the user cancels the payment flow.
  ///
  /// ⚠️ Always verify the nonce securely on your backend before completing payment.

  static Future<Map<String, dynamic>?> startCardPaymentWithBilling({
    required String authorization,
    required String cardNumber,
    required String expirationMonth,
    required String expirationYear,
    required String cvv,
    required String amount,
    String? streetAddress,
    String? postalCode,
  }) async {
    try {
      final result = await _kChannel.invokeMethod('startCardPayment', {
        'authorization': authorization,
        'request': {
          'cardNumber': cardNumber,
          'expirationMonth': expirationMonth,
          'expirationYear': expirationYear,
          'cvv': cvv,
          'amount': amount,
          'streetAddress': streetAddress,
          'postalCode': postalCode,
        },
      });

      if (result != null && result is Map) {
        return Map<String, dynamic>.from(result);
      }
    } on PlatformException catch (e) {
      return {'error': e.message};
    }
    return null;
  }

  /// Collects device data using Braintree's fraud detection tools.
  ///
  /// The [authorization] must be a valid client token or tokenization key.
  ///
  /// Device data is typically sent to your backend when creating
  /// a transaction to improve fraud detection accuracy.
  ///
  /// Returns:
  /// - A `String` containing device data.
  /// - `null` if device data collection fails.
  ///
  /// Note: Device data collection is optional but recommended
  /// for improved fraud protection.

  static Future<String?> collectDeviceData(String authorization) async {
    final deviceData = await _kChannel.invokeMethod('collectDeviceData', {
      'authorization': authorization,
    });

    return deviceData as String?;
  }

  /// Starts an Apple Pay payment using the native Braintree SDK (iOS only).
  ///
  /// Requires a valid [tokenizationKey].
  ///
  /// Parameters:
  /// - [amount] → Payment amount as a string (e.g., "10.99").
  /// - [displayName] → The label shown in the Apple Pay sheet.
  /// - [companyName] → Your company name.
  /// - [countryCode] → ISO country code (default: "US").
  /// - [currencyCode] → ISO currency code (default: "USD").
  /// - [merchantIdentifier] → Optional Apple Pay merchant identifier.
  ///
  /// Returns:
  /// - A `Map<String, dynamic>` containing:
  ///     - `nonce` → The payment method nonce on success.
  /// - An empty map or `null` if the user cancels.
  /// - `null` if a platform exception occurs.
  ///
  /// ⚠️ Apple Pay must be properly configured in your Apple Developer account.

  static Future<Map<String, dynamic>?> startApplePay({
    required String tokenizationKey,
    required String amount,
    required String displayName,
    required String companyName,
    String countryCode = 'US',
    String currencyCode = 'USD',
    String? merchantIdentifier,
  }) async {
    try {
      final result = await _kChannel.invokeMethod('tokenizeApplePay', {
        'authorization': tokenizationKey,
        'request': {
          'amount': amount,
          'label': displayName,
          'company': companyName,
          'merchantIdentifier': merchantIdentifier,
          'countryCode': countryCode,
          'currencyCode': currencyCode,
        }
      });

      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException {
      return null;
    }
  }

  /// Starts a Venmo payment using the native Braintree SDK (Android only).
  ///
  /// Requires a valid [tokenizationKey].
  ///
  /// Parameters:
  /// - [amount] → Optional payment amount (e.g., "10.00").
  /// - [usage] → Either "SINGLE_USE" or "MULTI_USE".
  /// - [appLinkUrl] → Your app-link URL or website domain also known as Universal Link.
  ///
  /// Venmo requires a universal link configured in your app.
  ///
  /// Example:
  ///
  /// Braintree.startVenmo(
  ///   tokenizationKey: "...",
  ///   appLinkUrl: "https://yourdomain.com/braintree-payments/venmo",
  ///   amount: "10.00",
  /// );
  ///
  /// The URL must match:
  ///
  /// • Apple Associated Domains entitlement
  /// • AASA file
  /// • Venmo developer dashboard
  /// • Your app bundle ID
  ///
  /// Returns:
  /// - A `Map<String, dynamic>` containing:
  ///     - `nonce` → The Venmo payment method nonce.
  ///     - `username` → The Venmo username associated with the account.
  ///     - `deviceData` → Fraud detection device data (if available).
  /// - A map containing `error` if:
  ///     - The user cancels the Venmo flow.
  ///     - A platform error occurs.
  /// - `null` is not returned for Venmo cancellation (cancellation is treated as an error).
  ///
  /// Note: Venmo availability depends on region and user account eligibility.

  static Future<Map<String, dynamic>?> startVenmo({
    required String tokenizationKey,
    required String appLinkUrl,
    String? amount, // "10.00"
    String usage = "SINGLE_USE", // or "MULTI_USE"
  }) async {
    try {
      final result = await _kChannel.invokeMethod('startVenmo', {
        'tokenizationKey': tokenizationKey,
        'appLinkUrl': appLinkUrl,
        'amount': amount,
        'usage': usage,
      });

      if (result != null && result is Map) {
        return Map<String, dynamic>.from(result);
      }
    } on PlatformException catch (e) {
      return {'error': e.message};
    }
    return null;
  }

  /// Starts a Google Pay payment using the native Braintree SDK (Android only).
  ///
  /// Requires a valid [tokenizationKey].
  ///
  /// Parameters:
  /// - [amount] → Payment amount as a string (e.g., "19.99").
  /// - [currencyCode] → ISO currency code (e.g., "USD").
  /// - [merchantName] → Your merchant display name.
  /// - [environment] → Either "TEST" or "PRODUCTION".
  ///
  /// Returns:
  /// - A `Map<String, dynamic>` containing:
  ///     - `nonce` → The Google Pay payment method nonce.
  ///     - `deviceData` → Fraud detection device data (if available).
  /// - A map containing `error` if a platform error occurs.
  /// - `null` if the user cancels the Google Pay flow.
  ///
  /// ⚠️ Google Pay must be enabled in your AndroidManifest.
  /// ⚠️ Google Pay must be properly configured in your Google Developer Console.

  static Future<Map<String, dynamic>?> startGooglePay({
    required String tokenizationKey,
    required String amount,
    required String currencyCode,
    required String merchantName,
    required String environment, // "TEST" or "PRODUCTION"
  }) async {
    try {
      final result = await _kChannel.invokeMethod('startGooglePay', {
        'tokenizationKey': tokenizationKey,
        'amount': amount,
        'currencyCode': currencyCode,
        'googleMerchantName': merchantName,
        'environment': environment,
      });

      if (result != null && result is Map) {
        return Map<String, dynamic>.from(result);
      }
    } on PlatformException catch (e) {
      return {'error': e.message};
    }

    return null;
  }

  /// Starts a PayPal checkout flow using the native Braintree SDK.
  ///
  /// The [authorization] must be either a client token or tokenization key.
  ///
  /// Parameters:
  /// - [amount] → Payment amount as a string (e.g., "12.34").
  /// - [currencyCode] → ISO currency code (default: "USD").
  /// - [returnUrl] → Must match your application's URL scheme
  ///   (e.g., "com.yourapp.braintree://paypal").
  /// - [hasUserLocationConsent] → Whether the user has consented to location usage.
  ///
  /// Returns:
  /// - A `Map<String, dynamic>` containing:
  ///     - `nonce` → The PayPal payment method nonce.
  ///     - `email` → The PayPal account email (if available).
  ///     - `payerId` → The PayPal payer ID.
  ///     - `deviceData` → Fraud detection device data (if collected).
  /// - A map containing `error` if a platform error occurs.
  /// - `null` if the user cancels the PayPal flow.
  ///
  /// ⚠️ The return URL must match your AndroidManifest or iOS URL scheme configuration.
  /// ⚠️ Always verify the nonce on your backend before completing a transaction.

  static Future<Map<String, dynamic>?> startPayPal({
    required String authorization,
    required String amount,
    String currencyCode = "USD", // Default if not provided
    required String returnUrl,
    bool hasUserLocationConsent = false,
  }) async {
    try {
      final result = await _kChannel.invokeMethod('startPayPal', {
        'authorization': authorization,
        'amount': amount,
        'currencyCode': currencyCode,
        'returnUrl': returnUrl,
        'hasUserLocationConsent': hasUserLocationConsent,
      });

      if (result != null && result is Map) {
        return Map<String, dynamic>.from(result);
      }
    } on PlatformException catch (e) {
      return {'error': e.message};
    }
    return null;
  }

}