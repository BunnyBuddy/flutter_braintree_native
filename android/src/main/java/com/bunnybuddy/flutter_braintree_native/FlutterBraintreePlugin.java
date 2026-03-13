package com.bunnybuddy.flutter_braintree_native;

import android.app.Activity;
import android.content.Intent;
import android.util.Log;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener;

public class FlutterBraintreePlugin implements FlutterPlugin, ActivityAware, MethodCallHandler, ActivityResultListener {
    private static final int CUSTOM_ACTIVITY_REQUEST_CODE = 0x420;
    private static final int GOOGLE_PAY_REQUEST_CODE = 0x999;
    private static final int CREDIT_CARD_REQUEST_CODE = 0x888;
    private static final int VENMO_REQUEST_CODE = 0x550;
    private static final int PAYPAL_REQUEST_CODE = 0x777;
    private Activity activity;
    private Result activeResult;
    private MethodChannel channel;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), "flutter_braintree.custom");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if (activeResult != null) {
            result.error("already_running", "Cannot launch another custom activity while one is already running.", null);
            return;
        }

        if (activity == null) {
            result.error("no_activity", "Plugin is not attached to an Activity.", null);
            return;
        }

        activeResult = result;

        switch (call.method) {
            case "startCardPayment" -> {
                String resolvedAuth = resolveAuthorization(call);
                if (resolvedAuth == null) {
                    activeResult.error("braintree_error", "Authorization not specified (no clientToken or tokenizationKey)", null);
                    activeResult = null;
                    return;
                }
                Map<String, Object> request = call.argument("request");
                if (request == null) {
                    activeResult.error("invalid_args", "request is null", null);
                    activeResult = null;
                    return;
                }
                Boolean require3DS = call.argument("require3DS");
                boolean force3DS = require3DS != null && require3DS;

                Boolean forceChallenge = call.argument("forceChallenge");
                boolean challenge = forceChallenge != null && forceChallenge;

                Intent intent = new Intent(activity, CardPaymentActivity.class);
                intent.putExtra("authorization", resolvedAuth);
                intent.putExtra("require3DS", force3DS);
                intent.putExtra("forceChallenge", challenge);
                intent.putExtra("cardNumber", (String) request.get("cardNumber"));
                intent.putExtra("expirationMonth", (String) request.get("expirationMonth"));
                intent.putExtra("expirationYear", (String) request.get("expirationYear"));
                intent.putExtra("cvv", (String) request.get("cvv"));
                intent.putExtra("amount", (String) request.get("amount"));
                intent.putExtra("streetAddress", (String) request.get("streetAddress"));
                intent.putExtra("postalCode", (String) request.get("postalCode"));
                startActivityForResultSafely(intent, CREDIT_CARD_REQUEST_CODE);
            }
            case "collectDeviceData" -> {
                String resolvedAuth = resolveAuthorization(call);
                if (resolvedAuth == null) {
                    activeResult.error("braintree_error", "Authorization not specified (no clientToken or tokenizationKey)", null);
                    activeResult = null;
                    return;
                }
                Intent intent = new Intent(activity, FlutterBraintreeCustom.class);
                intent.putExtra("type", "collectDeviceData");
                intent.putExtra("authorization", resolvedAuth);
                startActivityForResultSafely(intent, CUSTOM_ACTIVITY_REQUEST_CODE);
            }
            case "startGooglePay" -> {
                String resolvedAuth = resolveAuthorization(call);
                if (resolvedAuth == null) {
                    activeResult.error("braintree_error", "Authorization not specified (no clientToken or tokenizationKey)", null);
                    activeResult = null;
                    return;
                }
                String amount = call.argument("amount");
                String currencyCode = call.argument("currencyCode");
                String googleMerchantName = call.argument("googleMerchantName");
                String environment = call.argument("environment");

                Intent intent = new Intent(activity, GooglePayActivity.class);
                intent.putExtra("amount", amount);
                intent.putExtra("currencyCode", currencyCode);
                intent.putExtra("authorization", resolvedAuth);
                intent.putExtra("googleMerchantName", googleMerchantName);
                intent.putExtra("environment", environment);
                startActivityForResultSafely(intent, GOOGLE_PAY_REQUEST_CODE);
            }
            case "startVenmo" -> {
                String resolvedAuth = resolveAuthorization(call);
                if (resolvedAuth == null) {
                    activeResult.error("braintree_error", "Authorization not specified (no clientToken or tokenizationKey)", null);
                    activeResult = null;
                    return;
                }
                String appLinkUrl = call.argument("appLinkUrl");
                String amount = call.argument("amount");
                String usage = call.argument("usage");

                Intent intent = new Intent(activity, VenmoActivity.class);
                intent.putExtra("authorization", resolvedAuth);
                intent.putExtra("amount", amount);
                intent.putExtra("usage", usage);
                intent.putExtra("appLinkUrl", appLinkUrl);
                startActivityForResultSafely(intent, VENMO_REQUEST_CODE);
            }
            case "startPayPal" -> {
                String resolvedAuth = resolveAuthorization(call);
                if (resolvedAuth == null) {
                    activeResult.error("braintree_error", "Authorization not specified (no clientToken or tokenizationKey)", null);
                    activeResult = null;
                    return;
                }
                String amount = call.argument("amount");
                String currencyCode = call.argument("currencyCode");
                String returnUrl = call.argument("returnUrl");
                Boolean userLocationConsent = call.argument("hasUserLocationConsent");

                Intent intent = new Intent(activity, PayPalCheckoutActivity.class);
                intent.putExtra("authorization", resolvedAuth);
                intent.putExtra("amount", amount);
                intent.putExtra("currencyCode", currencyCode);
                intent.putExtra("returnUrl", returnUrl);
                intent.putExtra("hasUserLocationConsent", userLocationConsent != null && userLocationConsent);
                startActivityForResultSafely(intent, PAYPAL_REQUEST_CODE);
            }
            default -> {
                result.notImplemented();
                activeResult = null;
            }
        }
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (activeResult == null) return false;

        switch (requestCode) {
            case CUSTOM_ACTIVITY_REQUEST_CODE:
                if (resultCode == Activity.RESULT_OK && data != null) {
                    String type = data.getStringExtra("type");
                    if ("paymentMethodNonce".equals(type)) {
                        activeResult.success(data.getSerializableExtra("paymentMethodNonce"));
                    } else if ("deviceData".equals(type)) {
                        activeResult.success(data.getStringExtra("deviceData"));
                    } else {
                        activeResult.error("error", "Invalid activity result type.", null);
                    }
                } else if (resultCode == Activity.RESULT_CANCELED) {
                    String errorMessage = data != null ? data.getStringExtra("error") : null;
                    if (errorMessage == null || errorMessage.isEmpty()) {
                        activeResult.success(null);
                    } else {
                        activeResult.error("canceled", errorMessage, null);
                    }
                } else {
                    String errorMessage = data != null ? data.getStringExtra("error") : "Unknown error";
                    activeResult.error("error", errorMessage, null);
                }
                activeResult = null;
                return true;
            case PAYPAL_REQUEST_CODE:
                if (resultCode == Activity.RESULT_OK && data != null) {
                    String nonce = data.getStringExtra("nonce");
                    String email = data.getStringExtra("email");
                    String payerId = data.getStringExtra("payerId");
                    String deviceData = data.getStringExtra("deviceData");

                    Map<String, Object> resultMap = new HashMap<>();
                    resultMap.put("nonce", nonce);
                    resultMap.put("email", email);
                    resultMap.put("payerId", payerId);
                    resultMap.put("deviceData", deviceData);
                    activeResult.success(resultMap);
                } else if (resultCode == Activity.RESULT_CANCELED) {
                    if (data == null || !data.hasExtra("error")) {
                        activeResult.success(null);
                    } else {
                        activeResult.error("canceled", data.getStringExtra("error"), null);
                    }
                } else {
                    String error = data != null ? data.getStringExtra("error") : "Unknown PayPal error";
                    activeResult.error("error", error, null);
                }
                activeResult = null;
                return true;
            case GOOGLE_PAY_REQUEST_CODE:
                if (resultCode == Activity.RESULT_OK && data != null) {
                    String nonce = data.getStringExtra("nonce");
                    String deviceData = data.getStringExtra("deviceData");
                    Map<String, Object> resultMap = new HashMap<>();
                    resultMap.put("nonce", nonce);
                    resultMap.put("deviceData", deviceData);
                    activeResult.success(resultMap);
                } else if (resultCode == Activity.RESULT_CANCELED) {
                    if (data == null || !data.hasExtra("error")) {
                        Log.w("BT_GOOGLE_PAY", "User cancelled Google Pay flow.");
                        activeResult.success(null);
                    } else {
                        activeResult.error("canceled", data.getStringExtra("error"), null);
                    }
                } else {
                    String error = data != null ? data.getStringExtra("error") : "Unknown error";
                    activeResult.error("error", error, null);
                }
                activeResult = null;
                return true;
            case CREDIT_CARD_REQUEST_CODE:
                if (resultCode == Activity.RESULT_OK && data != null) {
                    String nonce = data.getStringExtra("nonce");
                    String deviceData = data.getStringExtra("deviceData");
                    boolean liabilityShifted = data.getBooleanExtra("liabilityShifted", false);
                    boolean liabilityShiftPossible = data.getBooleanExtra("liabilityShiftPossible", false);

                    Map<String, Object> resultMap = new HashMap<>();
                    resultMap.put("nonce", nonce);
                    resultMap.put("deviceData", deviceData);
                    resultMap.put("liabilityShifted", liabilityShifted);
                    resultMap.put("liabilityShiftPossible", liabilityShiftPossible);
                    activeResult.success(resultMap);
                } else if (resultCode == Activity.RESULT_CANCELED) {
                    if (data == null || !data.hasExtra("error")) {
                        Log.w("BT_CARD_3DS", "User cancelled card payment flow.");
                        activeResult.success(null);
                    } else {
                        activeResult.error("canceled", data.getStringExtra("error"), null);
                    }
                } else {
                    String error = data != null ? data.getStringExtra("error") : "Unknown card error";
                    activeResult.error("error", error, null);
                }
                activeResult = null;
                return true;
            case VENMO_REQUEST_CODE:
                if (resultCode == Activity.RESULT_OK && data != null) {
                    String nonce = data.getStringExtra("nonce");
                    String username = data.getStringExtra("username");
                    String deviceData = data.getStringExtra("deviceData");
                    Map<String, Object> resultMap = new HashMap<>();
                    resultMap.put("nonce", nonce);
                    resultMap.put("username", username);
                    resultMap.put("deviceData", deviceData);
                    activeResult.success(resultMap);
                } else if (resultCode == Activity.RESULT_CANCELED) {
                    activeResult.error("canceled", "User cancelled Venmo", null);
                } else {
                    String error = data != null ? data.getStringExtra("error") : "Unknown Venmo error";
                    activeResult.error("error", error, null);
                }
                activeResult = null;
                return true;
            default:
                return false;
        }
    }

    private String resolveAuthorization(MethodCall call) {
        String clientToken = call.argument("clientToken");
        String tokenizationKey = call.argument("tokenizationKey");
        String authorization = call.argument("authorization");

        if (clientToken != null && !clientToken.isEmpty()) return clientToken;
        if (tokenizationKey != null && !tokenizationKey.isEmpty()) return tokenizationKey;
        if (authorization != null && !authorization.isEmpty()) return authorization;

        return null;
    }

    private void startActivityForResultSafely(Intent intent, int requestCode) {
        if (intent.resolveActivity(activity.getPackageManager()) == null) {
            activeResult.error("activity_not_found", "Unable to launch payment activity.", null);
            activeResult = null;
            return;
        }
        activity.startActivityForResult(intent, requestCode);
    }
}