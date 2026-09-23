import ballerina/pdf;
import ballerina/log;

function generateDonationReceipt(SalesforceDonation notification) returns error? {
    string txnId = notification.Transaction_Id__c ?: "";
    string name = notification.Donor_Name__c ?: "";
    string email = notification.Donor_Email__c ?: "";
    string amount = (notification.Amount__c ?: 0).toString();
    string paymentMode = notification.Payment_Mode__c ?: "";
    if txnId == "" {
        log:printInfo("Skipping receipt - partial CDC event, missing Transaction ID");
        return;
    }
    string receiptHtml = string `
        <h1>Donation Receipt</h1>
        <table>
            <tr><td>Transaction ID</td><td>${txnId}</td></tr>
            <tr><td>Donor Name</td><td>${name}</td></tr>
            <tr><td>Donor Email</td><td>${email}</td></tr>
            <tr><td>Amount</td><td>${amount}</td></tr>
            <tr><td>Payment Mode</td><td>${paymentMode}</td></tr>
        </table>`;
    byte[] receiptPdf = check pdf:parseHtml(receiptHtml, pageSize = pdf:A4, margins = {top: 36, right: 36, bottom: 36, left: 36});
    string receiptFileName = string `receipts/receipt_${txnId}.pdf`;
    check ftpClient->putBytes(receiptFileName, receiptPdf);
    log:printInfo("Donation receipt is updated on the SFTP server", filePath = receiptFileName);
}