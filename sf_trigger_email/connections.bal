
import ballerinax/googleapis.gmail;
import ballerinax/salesforce;

final gmail:Client gmailClient = check new ({
    auth: {
        refreshToken: gmailRefreshToken,
        clientId: gmailClientId,
        clientSecret: gmailClientSecret
    }
});

final salesforce:Client sfClient = check new ({
    baseUrl: instanceUrl,
    auth: {
        clientId: clientId,
        clientSecret: clientSecret,
        refreshToken: refreshToken,
        refreshUrl: refreshUrl
    }
});
