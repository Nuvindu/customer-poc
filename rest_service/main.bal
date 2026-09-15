import ballerina/http;

listener http:Listener httpDefaultListener = http:getDefaultListener();

service / on httpDefaultListener {
    resource function post process(@http:Payload ProcessingRequest payload) returns FileProcessingResponse|error {
        do {
            FileProcessingResponse fileProcessingResponse = check processFile(payload.fileName);
            return fileProcessingResponse;
        } on fail error err {
            // handle error
            return error("unhandled error", err);
        }
    }

}
