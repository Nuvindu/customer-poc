import ballerina/lang.value;
import ballerinax/salesforce.pubsub;
import ballerina/io;

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
    subscriptionConfig: {
        initialReplay: "LATEST"
    }
});

service pubsub:Service /data/Donation__ChangeEvent on pubsubListener {
    remote function onEvent(pubsub:Event event) returns error? {
        io:println("Event occurred");
        SalesforceDonation|error salesforceData = value:cloneWithType(event.payload["changedData"]);
        if salesforceData !is error {
            check sendEmailNotification(salesforceData);
        } else {
            io:println("Error occurred", salesforceData);
        }

    }
}

