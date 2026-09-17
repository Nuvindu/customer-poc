import ballerina/io;
import ballerina/lang.'decimal as decimal;
import ballerina/oauth2;
import ballerinax/salesforce.pubsub;

configurable string instanceUrl = ?;
configurable string tenantId = ?;
configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string refreshToken = ?;
configurable string refreshUrl = ?;

type Donation record {
    string Name?;
    string Donor_Name__c?;
    string Donor_Email__c?;
    string Donor_Id__c?;
    decimal Amount__c?;
    int Donation_Date__c?;
    string Payment_Mode__c?;
    string Transaction_Id__c?;
    string OwnerId?;
    string CreatedById?;
    string LastModifiedById?;
};

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

isolated function toDonation(pubsub:Payload changedData) returns Donation|error {
    map<anydata> fields = changedData.clone();
    anydata? amount = fields["Amount__c"];
    if amount is float {
        fields["Amount__c"] = <decimal>amount;
    } else if amount is int {
        fields["Amount__c"] = <decimal>amount;
    } else if amount is string {
        fields["Amount__c"] = check decimal:fromString(amount);
    }
    return fields.cloneWithType(Donation);
}