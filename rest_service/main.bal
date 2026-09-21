import ballerina/http;

listener http:Listener httpDefaultListener = http:getDefaultListener();

service / on httpDefaultListener {
    resource function post process(@http:Payload ProcessingRequest payload) returns FileProcessingResponse|error {
        do {
            FileProcessingResponse|error fileProcessingResponse = processFile(payload.fileName);
            if fileProcessingResponse is error {
                string errorMsg = fileProcessingResponse.message();
                if errorMsg.includes("No such file") || errorMsg.includes("not found") || errorMsg.includes("does not exist") {
                    return error(string `File '${payload.fileName}' not found on the SFTP server`);
                }
            }
            return fileProcessingResponse;
        } on fail error err {
            // handle error
            return error("unhandled error", err);
        }
    }

}
