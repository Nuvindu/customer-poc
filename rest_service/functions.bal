import ballerina/data.csv;
import ballerina/file;
import ballerina/io;
import ballerina/lang.array;

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
        }
    }
}

function persist(string stateStorePath) returns error? {
    check io:fileWriteJson(stateStorePath, processingState.toJson());
}

function writeRejectionReport(DonationEntry rejected) returns error? {
    string reportName = string `rejected.csv`;

    string[][] lines = [["transactionId"]];
    foreach DonationEntryItem item in rejected {
        lines.push([item.transactionId]);
    }
    check ftpClient->putCsv(reportName, lines);
}