

import ballerinax/salesforce.pubsub;

function transformToDonationNotification(pubsub:Payload changedData) returns DonationNotification|error {
    return {
        donorName: (changedData["Donor_Name__c"] ?: "").toString(),
        donorEmail: (changedData["Donor_Email__c"] ?: "").toString(),
        amount: check decimal:fromString((changedData["Amount__c"] ?: 0).toString())
    };
}