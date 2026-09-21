import ballerina/io;
import ballerina/lang.value;
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

service /data/Donation__ChangeEvent on donationEvents {
    remote function onEvent(pubsub:Event event) returns error? {
        pubsub:Payload payload = event.payload;
        SalesforceDonation salesforceDonation = check value:cloneWithType(payload["changedData"]);
        check donationsProducer->send({
            topic: kafkaTopic,
            value: salesforceDonation
        });
        io:println("Published event to Kafka topic ", kafkaTopic);
    }

    remote function onError(pubsub:ListenerError err) returns error? {
        io:println("Donation CDC listener stopped: ", {
                                                          operation: err.operation,
                                                          topic: err.topic,
                                                          grpcStatus: err.grpcStatus
                                                      });
    }
}
