
import ballerina/log;
import ballerinax/googleapis.gmail;

const string EMAIL_SUBJECT_TEMPLATE = "Thank you for your donation, ${donorName}!";

const string EMAIL_BODY_TEMPLATE = "Dear ${donorName},\n\nThank you for your generous donation of $${amount}.\n\nTransaction Details:\n  Transaction ID: ${transactionId}\n  Donation Date: ${donationDate}\n  Payment Mode: ${paymentMode}\n\nWe truly appreciate your continued support.\n\nBest regards,\nThe Restos Team";

function renderTemplate(string template, map<string> values) returns string {
    string result = template;
    foreach [string, string] [key, value] in values.entries() {
        string placeholder = "${" + key + "}";
        int? idx = result.indexOf(placeholder);
        while idx is int {
            result = result.substring(0, idx) + value + result.substring(idx + placeholder.length());
            idx = result.indexOf(placeholder);
        }
    }
    return result;
}

function sendEmailNotification(DonationNotification notification) returns error? {
    map<string> templateValues = {
        "donorName": notification.donorName,
        "amount": notification.amount.toString(),
        "transactionId": notification.transactionId,
        "donationDate": notification.donationDate,
        "paymentMode": notification.paymentMode
    };

    string subject = renderTemplate(EMAIL_SUBJECT_TEMPLATE, templateValues);
    string body = renderTemplate(EMAIL_BODY_TEMPLATE, templateValues);

    gmail:MessageRequest emailMessage = {
        to: [notification.donorEmail],
        subject: subject,
        bodyInText: body
    };

    _ = check gmailClient->/users/me/messages/send.post(emailMessage);
    log:printInfo("Email notification sent", donorEmail = notification.donorEmail, transactionId = notification.transactionId);
}
