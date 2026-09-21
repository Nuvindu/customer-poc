import ballerina/data.csv;
import ballerina/file;
import ballerina/io;
import ballerina/lang.array;
import ballerina/log;
import ballerinax/googleapis.gmail;
import ballerinax/salesforce.bulkv2;

map<string> processingState = {}; // couldnt create this using WI

function processFile(string fileName) returns FileProcessingResponse|error {
    string stateStorePath = "/tmp/processing_state.json";
    check sync(stateStorePath);
    string content = check ftpClient->getText(string `${fileName}`);
    DonationEntry entries = check csv:parseString(string `${content}`);
    DonationEntry valid = [];
    DonationEntry rejected = [];
    foreach DonationEntryItem entry in entries {
        if processingState[entry.transactionId] == "success" {
            continue;
        }
        error? errorResult = validate(entry);
        if errorResult is error {
            processingState[entry.transactionId] = "rejected";
            array:push(rejected, entry);
            continue;
        }
        processingState[entry.transactionId] = "pending";
        array:push(valid, entry);
    }
    if rejected.length() > 0 {
        check writeRejectionReport(rejected);
        check sendRejectionEmail(rejected);
    }
    if valid.length() > 0 {
        check upsertToSalesforce(valid);
    }
    foreach DonationEntryItem entry in valid {
        processingState[entry.transactionId] = "success";
    }
    check persist(stateStorePath);
    return {
        fileName,
        validEntries: valid
    };
}

function validate(DonationEntryItem entry) returns error? {
    if entry.amount <= 0d {
        return error("Amount should be greater than zero");
    }
}

function sync(string stateStorePath) returns error? {
    boolean exists = check file:test(string `${stateStorePath}`, "EXISTS");
    if exists {
        json|error content = io:fileReadJson(stateStorePath);
        if content is json {
            processingState = check content.cloneWithType(); // couldnt create this using WI
        } else {
            processingState = {};
        }
    } else {
        processingState = {};
    }
}

function persist(string stateStorePath) returns error? {
    check io:fileWriteJson(stateStorePath, processingState.toJson());
}

function upsertToSalesforce(DonationEntry valid) returns error? {
    bulkv2:BulkCreatePayload jobPayload = {
        'object: "Donation__c",
        operation: "upsert",
        externalIdFieldName: "Transaction_Id__c",
        contentType: "CSV"
    };
    bulkv2:BulkJob job = check sfClient->createIngestJob(jobPayload);
    string[][] csvData = [
        [
            "Transaction_Id__c",
            "Donor_Id__c",
            "Donor_Name__c",
            "Donor_Email__c",
            "Amount__c",
            "Payment_Mode__c",
            "Donation_Date__c"
        ]
    ];
    foreach DonationEntryItem entry in valid {
        SalesforceEntry mapped = transformToSalesforceEntry(entry);
        array:push(csvData, [
                    mapped.transactionId,
                    mapped.donorId,
                    mapped.donorName,
                    mapped.donorEmail,
                    mapped.amount.toString(),
                    mapped.paymentMode,
                    mapped.donationDate
                ]);
    }
    check sfClient->addBatch(job.id, csvData);
    _ = check sfClient->closeIngestJob(job.id);
}

function writeRejectionReport(DonationEntry rejected) returns error? {
    string reportName = string `rejected.csv`;

    string[][] lines = [["transactionId", "donorId", "donorName", "donorEmail", "amount", "paymentMode", "donationDate"]];
    foreach DonationEntryItem item in rejected {
        lines.push([item.transactionId, item.donorId, item.donorName, item.donorEmail, item.amount.toString(), item.paymentMode, item.donationDate]);
    }
    check ftpClient->putCsv(reportName, lines);
}

function sendRejectionEmail(DonationEntry rejected) returns error? {
    string subject = string `Donation Processing - Rejected Entries`;
    string entryRows = "";
    foreach DonationEntryItem item in rejected {
        entryRows = entryRows + string `
  - Transaction ID: ${item.transactionId}
    Donor ID: ${item.donorId}
    Donor Name: ${item.donorName}
    Donor Email: ${item.donorEmail}
    Amount: $${item.amount}
    Payment Mode: ${item.paymentMode}
    Donation Date: ${item.donationDate}
`;
    }
    string body = string `The following ${rejected.length()} donation entries were rejected during processing:
${entryRows}
Please review and correct these entries before resubmitting.

Best regards,
The Restos Team`;

    gmail:MessageRequest emailMessage = {
        to: [rejectionNotifyEmail],
        subject: subject,
        bodyInText: body
    };
    _ = check gmailClient->/users/me/messages/send.post(emailMessage);
    log:printInfo("Rejection summary email sent", recipient = rejectionNotifyEmail, rejectedCount = rejected.length());
}
