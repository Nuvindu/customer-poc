import ballerina/log;

function sendEmailNotification(SalesforceDonation notification) returns error? {
    string? email = notification.Donor_Email__c;
    string? name = notification.Donor_Name__c;
    decimal? amount = notification.Amount__c;
    if email is () || name is () || amount is () {
        log:printInfo("Skipping email - partial CDC event, missing required fields");
        return;
    }
    _ = check gmailClient->/users/[string `me`]/messages/send.post({
        to: [email],
        subject: "Thank you for your Donation, " + name,
        bodyInText: string `Hi ${name},
    Thank you for your generous donation of ${amount.toString()}`
    });
    log:printInfo("Email notification sent", donorEmail = email);
}