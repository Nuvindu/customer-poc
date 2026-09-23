import ballerina/log;
import ballerina/pdf;
import ballerinax/googleapis.gmail;

function sendEmailNotification(SalesforceDonation notification) returns error? {
    gmail:Message result = check gmailClient->/users/[string `me`]/messages/send.post({
        to: [
            notification.Donor_Email__c
        ],
        subject: "Thank you for your Donation, " + notification.Donor_Name__c,
        bodyInText: string `Hi ${notification.Donor_Name__c},
    Thank you for your generous donation of ${notification.Amount__c.toString()}`
    });
    log:printInfo("Email notification sent", donorEmail = notification.Donor_Email__c);
}

function generateDonationReceipt(SalesforceDonation notification) returns error? {
    string receiptHtml = string `
        <h1>Donation Receipt</h1>
        <table>
            <tr><td>Transaction ID</td><td>${notification.Transaction_Id__c}</td></tr>
            <tr><td>Donor Name</td><td>${notification.Donor_Name__c}</td></tr>
            <tr><td>Donor Email</td><td>${notification.Donor_Email__c}</td></tr>
            <tr><td>Amount</td><td>${notification.Amount__c.toString()}</td></tr>
            <tr><td>Payment Mode</td><td>${notification.Payment_Mode__c}</td></tr>
        </table>`;
    byte[] receiptPdf = check pdf:parseHtml(receiptHtml, pageSize = pdf:A4, margins = {top: 36, right: 36, bottom: 36, left: 36});
    string receiptFileName = string `receipts/receipt_${notification.Transaction_Id__c}.pdf`;
    check ftpClient->putBytes(receiptFileName, receiptPdf);
    log:printInfo("Donation receipt is updated on the SFTP server", filePath = receiptFileName);
}
