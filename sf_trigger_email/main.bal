
import ballerinax/salesforce;

listener salesforce:Listener salesforceListener = new ({
    baseUrl: baseUrl,
    auth: {
        refreshUrl: sfRefreshUrl,
        refreshToken: sfRefreshToken,
        clientId: sfClientId,
        clientSecret: sfClientSecret
    }
});

service salesforce:CdcService "/data/ChangeEvents" on salesforceListener {
    remote function onCreate(salesforce:EventData payload) returns error? {
        map<json> changedData = payload.changedData;
        DonationNotification notification = check transformToDonationNotification(changedData);
        check sendEmailNotification(notification);
    }

    remote function onUpdate(salesforce:EventData payload) returns error? {
    }

    remote function onDelete(salesforce:EventData payload) returns error? {
    }

    remote function onRestore(salesforce:EventData payload) returns error? {
    }
}
