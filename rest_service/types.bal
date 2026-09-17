
type FileProcessingResponse record {|
    string fileName;
    DonationEntry validEntries;
|};

type ProcessingRequest record {|
    string fileName;
|};

public type DonationEntryItem record {|
    string transactionId;
    string donorId;
    string donorName;
    string donorEmail;
    decimal amount;
    string paymentMode;
    string donationDate;
|};

public type DonationEntry DonationEntryItem[];

public type SalesforceEntry record {|
    string transactionId;
    string donorId;
    string donorName;
    string donorEmail;
    decimal amount;
    string paymentMode;
    string donationDate;
|};
