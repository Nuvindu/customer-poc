import ballerina/io;
import ballerina/lang.value;
import ballerinax/salesforce.pubsub;

listener pubsub:Listener donationEvents = check new ({
    connection: {
        auth: {
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

map<boolean> processedEvents = {};

service /data/Donation__ChangeEvent on donationEvents {
    remote function onEvent(pubsub:Event event) returns error? {
        string? eventId = event.eventId;
        if eventId is string {
            if processedEvents.hasKey(eventId) {
                return;
            }
            processedEvents[eventId] = true;
        }
        SalesforceDonation salesforceData = check value:cloneWithType(event.payload["changedData"]);
        check sendEmailNotification(salesforceData); 
    }

    remote function onError(pubsub:ListenerError err) returns error? {
        io:println("Donation CDC listener stopped: ", {
                                                          operation: err.operation,
                                                          topic: err.topic,
                                                          grpcStatus: err.grpcStatus
                                                      });
    }
}
