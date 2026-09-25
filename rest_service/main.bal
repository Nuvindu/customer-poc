import ballerina/http;
import ballerina/observe as _;
import ballerinax/moesif as _;

listener http:Listener httpDefaultListener = http:getDefaultListener();

service / on httpDefaultListener {
    resource function post process(@http:Payload ProcessingRequest payload) returns FileProcessingResponse|http:Conflict|error {
        do {
            FileProcessingResponse|error fileProcessingResponse = processFile(payload.fileName);
            if fileProcessingResponse is error {
                string errorMsg = fileProcessingResponse.message();
                if errorMsg.includes("No such file") || errorMsg.includes("not found") || errorMsg.includes("does not exist") {
                    return error(string `File '${payload.fileName}' not found on the SFTP server`);
                }
                return fileProcessingResponse;
            }
            if fileProcessingResponse.rejectedEntries.length() > 0 {
                return <http:Conflict>{body: fileProcessingResponse};
            }
            return fileProcessingResponse;
        } on fail error err {
            return error("unhandled error", err);
        }
    }

}
