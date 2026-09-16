
function transformToDonationNotification(map<json> changedData) returns DonationNotification|error {
    return {
        transactionId: (changedData["Transaction_Id__c"] ?: "").toString(),
        donorName: (changedData["Donor_Name__c"] ?: "").toString(),
        donorEmail: (changedData["Donor_Email__c"] ?: "").toString(),
        amount: check decimal:fromString((changedData["Amount__c"] ?: 0).toString()),
        paymentMode: (changedData["Payment_Mode__c"] ?: "").toString(),
        donationDate: (changedData["Donation_Date__c"] ?: "").toString()
    };
}
