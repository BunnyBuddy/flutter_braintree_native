import Flutter
import UIKit
import Braintree

public class BraintreeDeviceCollector: NSObject {

    public static func collectDeviceData(
    tokenizationKey: String,
    result: @escaping FlutterResult
    ) {

        let dataCollector = BTDataCollector(authorization: tokenizationKey)

        dataCollector.collectDeviceData { deviceData, error in
            if let error = error {
                result(
                    FlutterError(
                        code: "DEVICE_DATA_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    )
                )
            } else {
                print("✅ Device data collected: \(deviceData ?? "null")")
                result(deviceData)
            }
        }
    }
}
