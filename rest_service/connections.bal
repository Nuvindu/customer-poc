import ballerina/ftp;
import ballerinax/googleapis.gmail;
import ballerinax/salesforce.bulkv2;

final ftp:Client ftpClient = check new ({
    protocol: protocol,
    host: ftpHost,
    port: ftpPort,
    auth: {
        credentials: {
            username: ftpUsername,
            password: ftpPassword
        }
    }
});

final bulkv2:Client sfClient = check new ({
    baseUrl: sfBaseUrl,
    auth: {
        clientId: clientId,
        clientSecret: clientSecret,
        refreshToken: refreshToken,
        refreshUrl: refreshUrl
    }
});

final gmail:Client gmailClient = check new ({
    auth: {
        refreshToken: gmailRefreshToken,
        clientId: gmailClientId,
        clientSecret: gmailClientSecret
    }
});
