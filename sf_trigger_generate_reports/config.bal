import ballerina/ftp;

configurable string instanceUrl = ?;
configurable string tenantId = ?;
configurable string refreshUrl = ?;
configurable string refreshToken = ?;
configurable string clientId = ?;
configurable string clientSecret = ?;

configurable string ftpHost = ?;
configurable int ftpPort = ?;
configurable string ftpUsername = ?;
configurable string ftpPassword = ?;
configurable ftp:Protocol ftpProtocol = ?;