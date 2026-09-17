
function convertToSalesforceDate(string donationDate) returns string {
    string:RegExp dateSeparator = re `[/.]`;
    string[] dateParts = dateSeparator.split(donationDate);
    if dateParts.length() == 3 && dateParts[2].length() == 4 {
        return string `${dateParts[2]}-${dateParts[1]}-${dateParts[0]}`;
    }
    return donationDate;
}

public function transformToSalesforceEntry(DonationEntryItem donationEntry) returns SalesforceEntry => {
    transactionId: donationEntry.transactionId,
    donorId: donationEntry.donorId,
    donorName: donationEntry.donorName,
    donorEmail: donationEntry.donorEmail,
    amount: donationEntry.amount,
    paymentMode: donationEntry.paymentMode,
    donationDate: convertToSalesforceDate(donationEntry.donationDate)
};
