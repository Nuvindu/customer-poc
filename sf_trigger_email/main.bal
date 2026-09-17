import ballerina/io;
import ballerina/oauth2;
import ballerinax/salesforce.pubsub;

listener pubsub:Listener donationEvents = check new ({
    connection: {
        auth: <oauth2:RefreshTokenGrantConfig>{
            clientId,
            clientSecret,
            refreshToken,
            refreshUrl
        },
        instanceUrl,
        tenantId
    },
    subscriptionConfig: {
        initialReplay: pubsub:LATEST
    }
});

service /data/Donation__ChangeEvent on donationEvents {
    remote function onEvent(pubsub:Event event) returns error? {
        io:println("Donation CDC event");
        pubsub:Payload changedData = check event.payload["changedData"].ensureType();
        pubsub:Payload metadata = check event.payload["metadata"].ensureType();
        string[] changedFields = check metadata["changedFields"].ensureType();
        string[] nulledFields = check metadata["nulledFields"].ensureType();

        DonationNotification notification = check transformToDonationNotification(changedData);
        check sendEmailNotification(notification);
        io:println({
            topic: event.topic,
            replayId: event.replayId,
            changedFields,
            nulledFields,
            metadata,
            changedData
        });
    }

    remote function onError(pubsub:ListenerError err) returns error? {
        io:println("Donation CDC listener stopped: ", {
            operation: err.operation,
            topic: err.topic,
            grpcStatus: err.grpcStatus
        });
    }
}
