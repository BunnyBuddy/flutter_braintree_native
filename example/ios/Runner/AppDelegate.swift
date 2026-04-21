import Flutter
import UIKit
import Braintree

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {

        // Let Braintree handle Venmo / PayPal return
        if BTAppContextSwitcher.sharedInstance.handleOpen(url) {
            return true
        }

        return super.application(app, open: url, options: options)
    }
    
    override func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {

        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }

        return BTAppContextSwitcher.sharedInstance.handleOpen(url)
    }
}
