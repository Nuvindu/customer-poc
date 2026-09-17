import ballerina/io;
import ballerina/oauth2;
import ballerinax/kafka;
import ballerinax/salesforce.pubsub;

final kafka:Producer donationsProducer = check new (kafkaBootstrapServers, {
    securityProtocol: kafka:PROTOCOL_SSL,
    secureSocket: {
        cert: kafkaCaCertPath,
        key: {
            certFile: kafkaCertPath,
            keyFile: kafkaKeyPath
        }
    }
});

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
        DonationNotification notification = check transformToDonationNotification(changedData);
        check donationsProducer->send({
            topic: "donations",
            value: notification
        });
        io:println("Published event to Kafka topic 'donations'");
    }

    remote function onError(pubsub:ListenerError err) returns error? {
        io:println("Donation CDC listener stopped: ", {
            operation: err.operation,
            topic: err.topic,
            grpcStatus: err.grpcStatus
        });
    }
}
