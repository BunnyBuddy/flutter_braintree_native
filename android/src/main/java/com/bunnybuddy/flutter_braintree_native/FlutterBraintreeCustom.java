package com.bunnybuddy.flutter_braintree_native;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import com.braintreepayments.api.datacollector.DataCollector;
import com.braintreepayments.api.datacollector.DataCollectorRequest;
import com.braintreepayments.api.datacollector.DataCollectorResult;

public class FlutterBraintreeCustom extends AppCompatActivity {
    private String authorization;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_flutter_braintree_custom);

        Intent intent = getIntent();
        String clientToken = intent.getStringExtra("clientToken");
        String tokenizationKey = intent.getStringExtra("tokenizationKey");
        String authKey = intent.getStringExtra("authorization");

        authorization = clientToken != null ? clientToken
                : tokenizationKey != null ? tokenizationKey
                : authKey;

        String type = intent.getStringExtra("type");

        if (authorization == null || authorization.isEmpty()) {
            finishWithError("Missing authorization for device data collection");
            return;
        }

        if (!"collectDeviceData".equals(type)) {
            finishWithError("Invalid request type: " + type);
            return;
        }

        collectDeviceData();
    }

    @Override
    protected void onNewIntent(@NonNull Intent newIntent) {
        super.onNewIntent(newIntent);
        setIntent(newIntent);
    }

    protected void collectDeviceData() {
        DataCollector dataCollector = new DataCollector(this, authorization);
        DataCollectorRequest dataCollectorRequest = new DataCollectorRequest(false);
        dataCollector.collectDeviceData(this, dataCollectorRequest, dataCollectorResult -> {
            Intent intent = new Intent();
            if (dataCollectorResult instanceof DataCollectorResult.Success) {
                String deviceData = ((DataCollectorResult.Success) dataCollectorResult).getDeviceData();
                intent.putExtra("deviceData", deviceData);
            } else if (dataCollectorResult instanceof DataCollectorResult.Failure) {
                Exception e = ((DataCollectorResult.Failure) dataCollectorResult).getError();
                intent.putExtra("deviceDataError", e != null ? e.getMessage() : "Device data collection failed");
            }
            intent.putExtra("type", "deviceData");
            setResult(Activity.RESULT_OK, intent);
            finish();
        });
    }

    private void finishWithError(String error) {
        Intent result = new Intent();
        result.putExtra("error", error);
        setResult(Activity.RESULT_CANCELED, result);
        finish();
    }
}
