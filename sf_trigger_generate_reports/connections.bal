import ballerina/ftp;

final ftp:Client ftpClient = check new ({
    protocol: ftpProtocol,
    host: ftpHost,
    port: ftpPort,
    auth: {
        credentials: {
            username: ftpUsername,
            password: ftpPassword
        }
    }
});