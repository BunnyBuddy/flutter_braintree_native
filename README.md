# flutter_braintree_native

A Flutter plugin that wraps the official Braintree Android and iOS native SDKs, enabling fully custom payment flows built with Flutter.

Unlike older plugins, this package **does not rely on Braintree’s Drop-In**. Instead, it exposes native SDK functionality so you can design your own payment experience and stay aligned with modern Braintree integrations.

#### This is a community-driven package and is not officially affiliated with Braintree or PayPal.

Special thanks to [Pikaju](https://github.com/pikaju)
for the original Drop-In based implementation that inspired me to do this apparent rewrite.

| Platform | Card | PayPal | Google Pay | Venmo | Apple Pay |
|--------|------|--------|-----------|-----|----------|
| Android | ✅ | ✅ | ✅ | ✅ | ❌ |
| iOS | ✅ | ✅ | ❌ | ✅ | ✅ |

## ✨ Features

1. 💳 Credit Card payments (with optional 3D Secure and with optional billing address)
2. 🅿️ PayPal Checkout
3. 𝐠 Google Pay (Android)
4.  Apple Pay (IOS)
5. 🟣 Venmo
6. 📊 Device Data Collection (Fraud Detection)
7. 🔐 Native SDK integration (no WebView hacks or drop-in)

## 📦 Installation

Add flutter_braintree_native to your `pubspec.yaml` file:

```yaml
dependencies:
  ...
  flutter_braintree_native: <version>
```

Run:

```
flutter pub get
```

### 🔧 Android

You must [migrate to AndroidX.](https://flutter.dev/docs/development/packages-and-plugins/androidx-compatibility)  
In `/app/build.gradle`, set your `minSdkVersion` to at least `24`.

**Important:** Your app's URL scheme must begin with your app's package ID and end with `.braintree`. For example, if the Package ID is `com.your-company.your-app`, then your URL scheme should be `com.your-company.your-app.braintree`. `${applicationId}` is automatically applied with your app's
package when using Gradle.
**Note:** The scheme you define must use all lowercase letters. If your package contains underscores, the underscores should be removed when specifying the scheme in your Android Manifest.

### Google Pay (Android Only)

Add the wallet enabled meta-data tag to your `AndroidManifest.xml` (inside the `<application>` body):

```xml

<meta-data android:name="com.google.android.gms.wallet.api.enabled" android:value="true" />
```

### 🍎 iOS

You may need to add or uncomment the following line at the top of your `ios/Podfile`:

```ruby
platform :ios, '14.0'
```

### Apple Pay (iOS Only)
#### ⚠️ Important: Apple Pay requires additional Xcode configuration.
If not configured correctly, the Apple Pay sheet may briefly appear and then immediately dismiss.

1️⃣ Enable Apple Pay Capability

In Xcode:

```swift
Runner → Signing & Capabilities → + Capability → Apple Pay
```

Then select your Merchant ID.

If this capability is missing, Apple Pay will silently cancel.

2️⃣ Create a Merchant ID (Apple Developer)

Apple does not provide a shared test merchant ID.

You must:

Create a Merchant ID in the Apple Developer portal
Example:

1. merchant.com.yourcompany.yourapp
2. Generate an Apple Pay certificate (Sandbox & Production)
3. Upload the certificate to:
4. Braintree Control Panel → Processing → Apple Pay

**Warning:** Device data collection is not yet supported for iOS.

### For PayPal / Venmo / 3D Secure

⚠️ **Important:** Upon cancellation (user canceled the operation/payment) Venmo doesn't return null, (we handled user cancellation like this only for Venmo, the rest of the payment methods return null). It returns an error with the message "User canceled Venmo".

#### iOS Venmo / PayPal Redirect

Add the following to your AppDelegate:

```swift
override func application(_ app: UIApplication,
open url: URL,
options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    if BTAppContextSwitcher.sharedInstance.handleOpen(url) {
        return true
    }
    return super.application(app, open: url, options: options)
}
```

#### Return URL Configuration

Moreover, you need to specify the same URL scheme in your `Info.plist`:

```xml

<key>CFBundleURLTypes</key><array>
<dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLName</key>
    <string>com.your-company.your-app.braintree</string>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>com.your-company.your-app.braintree</string>
    </array>
</dict>
</array>
```

See the official [Braintree documentation](https://developer.paypal.com/braintree/docs/guides/payment-method-types-overview/) for a more detailed explanation.

## Usage Example

You must first create a [Braintree account](https://www.braintreepayments.com/). In your control panel you can create a tokenization key. You likely also want to set up a backend server. Make sure to read the [Braintree developer documentation](https://developers.braintreepayments.com/) so you
understand all key concepts.

In your code, import the plugin:

```dart
import 'package:flutter_braintree_native/flutter_braintree_native.dart';
```

You can then create your own user interface using Flutter or use Braintree's Custom UI.

### Braintree's native UI

Access the payment nonce (if successful):

```dart
// For example
final result = await
Braintree.startPayPal
(
authorization: BRAINTREE_TOKEN, // sandbox or production
amount: 10.12,
currencyCode: "USD",
returnUrl: "${Your Website or Domain Name}/mobile/paypal",
);

if (result != null) {
if (result.containsKey('error')) {
debugPrint("Error => ${result['error']}");
} else {
debugPrint("Nonce => ${result['nonce']}"); // This is your success token
}
}

// if you need the device data for your backend (only required in case of fraud detection so its optional)
String? deviceData = result["deviceData"];
```

### ⚠️ Security Notice

This plugin generates payment nonces only.
You must send the nonce to your backend server to create transactions securely.

Never complete payments directly from the client.

### 📌 Known Limitations

Venmo support has limited testing (sandbox support is restricted by region), so please test venmo at your end before using it in production.

Vaulting is not yet implemented.

Responses are currently returned as a generic Map. Strongly typed models are planned for a future release.

Contributions and improvements are welcome.

### 📄 License

[MIT License]((/LICENSE))
