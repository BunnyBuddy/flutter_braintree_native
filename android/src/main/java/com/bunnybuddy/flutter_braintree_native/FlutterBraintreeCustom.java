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
        try {
            Intent intent = getIntent();
            String clientToken = intent.getStringExtra("clientToken");
            String tokenizationKey = intent.getStringExtra("tokenizationKey");
            String authKey = intent.getStringExtra("authorization");

            authorization = clientToken != null ? clientToken
                    : tokenizationKey != null ? tokenizationKey
                    : authKey;

//            authorization = intent.getStringExtra("authorization");
            String type = intent.getStringExtra("type");

            assert type != null;
            if (type.equals("collectDeviceData")) {
                collectDeviceData();
            } else {
                throw new Exception("Invalid request type: " + type);
            }
        } catch (Exception e) {
            Intent result = new Intent();
            result.putExtra("error", e);
            setResult(2, result);
            finish();
            return;
        }
    }

    @Override
    protected void onNewIntent(@NonNull Intent newIntent) {
        super.onNewIntent(newIntent);
        setIntent(newIntent);
    }

    @Override
    protected void onStart() {
        super.onStart();
    }

    @Override
    protected void onResume() {
        super.onResume();
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
                intent.putExtra("deviceDataError", e.getMessage());
            }
            intent.putExtra("type", "deviceData");
            setResult(Activity.RESULT_OK, intent);
            finish();
        });
    }

}