## 0.1.6

### Added

* Added support for passing optional billing and customer information directly to `startCardPayment()`.
* Added support for additional 3D Secure billing fields:

    * Billing first name
    * Billing last name
    * Billing address
    * Billing city
    * Billing ZIP/postal code
    * Billing country code (ISO 3166-1 alpha-2)
    * Billing phone number
    * Email address

### Changed

* Unified the Android and iOS card payment implementations for feature parity.
* Updated Android and iOS 3D Secure flows to use the same request structure and billing information.
* Simplified the Flutter API by allowing billing information to be passed directly through `startCardPayment()`.
* Improved API documentation for card payments and 3D Secure.
* Deprecated `startCardPaymentWithBilling()`. Use `startCardPayment()` instead. The deprecated method will be removed in the next major release.

### Fixed

* Improved Android 3D Secure handling and authentication flow.
* Improved iOS 3D Secure request construction to better match the Android implementation.
* Fixed several inconsistencies between Android and iOS card payment responses.

## 0.1.5

- Updated android side Braintree dependencies
- Updated code for Venmo on both sides android and ios + added universal link support

## 0.1.4

- Resolved an issue in example app on ios side and updated readme file
- Made 3D Secure optional, now you can pass true/false to enable/disable 3D Secure for card payment
- Now you can force 3DS challenge even if authentication is set to frictionless from backend

## 0.1.3

- Improved stability for ios devices
- Resolved an issue in AppDelegate.swift which made it impossible to run the example app on iOS

## 0.1.2

- Improved stability
- Resolved some edge cases in card payment and venmo payment

## 0.1.1

- Improve README documentation
- Add platform support table
- Minor documentation improvements

## 0.1.0

- Initial release
- Credit Card (with 3DS and billing)
- PayPal
- Google Pay (Android)
- Apple Pay (iOS)
- Venmo
- Device Data collection