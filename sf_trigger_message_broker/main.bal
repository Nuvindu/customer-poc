import ballerina/io;
import ballerina/lang.value;
import ballerinax/salesforce.pubsub;

listener pubsub:Listener pubsubListener = new (config = {
    connection: {
        auth: {
            refreshUrl: refreshUrl,
            refreshToken: refreshToken,
            clientId: clientId,
            clientSecret: clientSecret
        },
        instanceUrl: string `${instanceUrl}`,
        tenantId: string `${tenantId}`
    },
    subscriptionConfig: {
        initialReplay: "LATEST"
    }
});

service pubsub:Service /data/Donation__ChangeEvent on pubsubListener {
    remote function onEvent(pubsub:Event event) returns error? {
        pubsub:Payload payload = event.payload;
        SalesforceDonation salesforceDonation = check value:cloneWithType(payload["changedData"]);
        check kafkaProducer->send({
            topic: kafkaTopic,
            value: salesforceDonation
        });
        io:println("Published event to Kafka topic ", kafkaTopic);
    }
}
