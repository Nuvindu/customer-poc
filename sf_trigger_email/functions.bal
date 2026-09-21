import ballerina/log;
import ballerinax/googleapis.gmail;

function sendEmailNotification(SalesforceDonation notification) returns error? {
    gmail:Message result = check gmailClient->/users/[string `me`]/messages/send.post({
    to: [
        notification.Donor_Email__c
    ],
    subject: "Thank you for your Donation, " + notification.Donor_Name__c,
    bodyInText: "Thank you for your generous donation of " + notification.Amount__c.toString()
});
    log:printInfo("Email notification sent", donorEmail = notification.Donor_Email__c);
}
