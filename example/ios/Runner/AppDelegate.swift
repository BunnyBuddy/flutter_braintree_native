import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Handle Universal Link redirects

    override func application(_ app: UIApplication,
    openurl: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {

        // Let Braintree decide if this belongs to Venmo / PayPal / etc
        if BTAppContextSwitcher.sharedInstance.handleOpen(url) {
            return true
        }

        return super.application(app, open: url, options: options)
    }
}