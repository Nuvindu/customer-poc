import ballerina/lang.value;
import ballerinax/salesforce.pubsub;

listener pubsub:Listener pubsubListener = new ({
    connection: {
        instanceUrl: string `${instanceUrl}`,
        tenantId: string `${tenantId}`,
        auth: {
            refreshUrl: refreshUrl,
            refreshToken: refreshToken,
            clientId: clientId,
            clientSecret: clientSecret
        }
    },
    subscriptionConfig: {}
});

service pubsub:Service /data/Donation__ChangeEvent on pubsubListener {
    remote function onEvent(pubsub:Event event) returns error? {
        SalesforceDonation salesforceData = check value:cloneWithType(event.payload["changedData"]);
        check sendEmailNotification(salesforceData);
    }
}

