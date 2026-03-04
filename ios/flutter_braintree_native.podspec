Pod::Spec.new do |s|
  s.name             = 'flutter_braintree_native'
  s.version          = '0.1.0'
  s.summary          = 'A Flutter plugin that wraps native sdks for Braintree Paypal, Venmo, Google Pay, Apple Pay, Card, Data Collector'
  s.description      = <<-DESC
  A Flutter plugin that wraps the Braintree Native SDKs (Not Drop-in).
                       DESC
  s.homepage         = 'https://github.com/BunnyBuddy/flutter_braintree_native'
  s.license          = { :file => '../LICENSE' }
  s.author           = {
    'Pikaju (Julien Scholz)' => 'https://github.com/pikaju',
    'BunnyBuddy (Bani Akram)' => 'https://github.com/BunnyBuddy'
  }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
#  s.public_header_files = 'Classes/**/*.h'
  s.module_name = 'flutter_braintree_native'
  s.static_framework = true
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_ENABLE_EXPLICIT_MODULES' => 'NO',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "$(BUILT_PRODUCTS_DIR)"',
  }
  s.dependency 'Flutter'

  s.dependency 'Braintree/Core', '~> 7.5.0'
  s.dependency 'Braintree/Card', '~> 7.5.0'
  s.dependency 'Braintree/PayPal', '~> 7.5.0'
  s.dependency 'Braintree/DataCollector', '~> 7.5.0'
  s.dependency 'Braintree/ApplePay', '~> 7.5.0'
  s.dependency 'Braintree/Venmo', '~> 7.5.0'
  s.dependency 'Braintree/ThreeDSecure', '~> 7.5.0'

  s.ios.deployment_target = '14.0'
  s.swift_version = '5.0'
end