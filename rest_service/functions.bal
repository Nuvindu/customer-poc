import ballerina/data.csv;
import ballerina/file;
import ballerina/io;
import ballerina/lang.array;
import ballerinax/salesforce.bulkv2;

map<string> processingState = {}; // couldnt create this using WI

function processFile(string fileName) returns FileProcessingResponse|error {
    string stateStorePath = "processing_state.json";
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
    if entry.amount < 0 {
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
        ["Transaction_Id__c", "Donor_Id__c", "Donor_Name__c", "Donor_Email__c", "Amount__c", "Payment_Mode__c", "Donation_Date__c"]
    ];
    foreach DonationEntryItem entry in valid {
        csvData.push([
            entry.transactionId,
            entry.donorId,
            entry.donorName,
            entry.donorEmail,
            entry.amount.toString(),
            entry.paymentMode,
            convertToIsoDate(entry.donationDate)
        ]);
    }
    check sfClient->addBatch(job.id, csvData);
    _ = check sfClient->closeIngestJob(job.id);
}

function convertToIsoDate(string date) returns string {
    string[] parts = re `/`.split(date);
    if parts.length() == 3 && parts[0].length() == 2 {
        return string `${parts[2]}-${parts[1]}-${parts[0]}`;
    }
    return date;
}

function writeRejectionReport(DonationEntry rejected) returns error? {
    string reportName = string `rejected.csv`;

    string[][] lines = [["transactionId"]];
    foreach DonationEntryItem item in rejected {
        lines.push([item.transactionId]);
    }
    check ftpClient->putCsv(reportName, lines);
}