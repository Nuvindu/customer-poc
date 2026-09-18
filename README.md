# Restos POC - Donation Processing Integration

A Ballerina workspace with three integrations that process donation data end-to-end: ingest CSV files, upsert to Salesforce, send email notifications, and publish events to Kafka.

## Architecture

```
CSV File (SFTP) 
    |
    v
[rest_service] ---> Salesforce Donation__c (Bulk API v2 Upsert)
                          |
                          | (CDC Events)
                          |
              +-----------+-----------+
              |                       |
              v                       v
    [sf_trigger_email]     [sf_trigger_message_broker]
     Send Gmail notify      Publish to Kafka topic
```

## Use Cases

### Use Case 1: Batch Donation Ingestion (rest_service)

An organization receives donation records as CSV files uploaded to an SFTP server. The `rest_service` provides a REST endpoint to trigger processing of these files. It downloads the CSV, validates each entry, rejects invalid records, and upserts the valid ones into Salesforce as `Donation__c` records using the Bulk API v2. This enables bulk ingestion of donations without manual Salesforce data entry.

### Use Case 2: Real-Time Email Notifications (sf_trigger_email)

When a donation record is created or updated in Salesforce (either via the bulk ingestion above or through any other means), a CDC (Change Data Capture) event fires. The `sf_trigger_email` service listens for these events and automatically sends a personalized thank-you email to the donor using the Gmail API. The email body is rendered from a FreeMarker-style template with `${placeholder}` substitution.

**Email template:**
```
Subject: Thank you for your donation, ${donorName}!

Dear ${donorName},

Thank you for your generous donation of $${amount}.

We truly appreciate your continued support.

Best regards,
The Restos Team
```

### Use Case 3: Event Streaming to Kafka (sf_trigger_message_broker)

The same CDC events are also consumed by `sf_trigger_message_broker`, which publishes the full donation record as a JSON message to an Apache Kafka `donations` topic over SSL/TLS. This enables downstream systems (analytics, reporting, audit logging, etc.) to consume donation events asynchronously.

## CSV File Format

The input CSV file must have the following columns:

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `transactionId` | string | Unique identifier for the donation transaction | `TXN-2001` |
| `donorId` | string | Unique identifier for the donor | `DON-2001` |
| `donorName` | string | Full name of the donor | `Sakura Tanaka` |
| `donorEmail` | string | Email address of the donor | `sakura.tanaka@example.jp` |
| `amount` | decimal | Donation amount (must be positive) | `250.00` |
| `paymentMode` | string | Payment method used | `CARD`, `BANK_TRANSFER`, `CHEQUE`, `CASH` |
| `donationDate` | string | Date of donation in DD/MM/YYYY format | `15/09/2026` |

**Example CSV:**
```csv
transactionId,donorId,donorName,donorEmail,amount,paymentMode,donationDate
TXN-2001,DON-2001,Sakura Tanaka,sakura.tanaka@example.jp,250.00,CARD,15/09/2026
TXN-2002,DON-2002,Marco Rossi,marco.rossi@example.it,75.25,BANK_TRANSFER,16/09/2026
TXN-2003,DON-2003,Fatima Al-Hassan,fatima.alhassan@example.ae,500.00,CHEQUE,17/09/2026
```

### CSV to Salesforce Field Mapping

| CSV Column | Salesforce Field | Transformation |
|------------|------------------|----------------|
| `transactionId` | `Transaction_Id__c` | Direct mapping (used as external ID for upsert) |
| `donorId` | `Donor_Id__c` | Direct mapping |
| `donorName` | `Donor_Name__c` | Direct mapping |
| `donorEmail` | `Donor_Email__c` | Direct mapping |
| `amount` | `Amount__c` | Direct mapping |
| `paymentMode` | `Payment_Mode__c` | Direct mapping |
| `donationDate` | `Donation_Date__c` | Date format converted from `DD/MM/YYYY` to `YYYY-MM-DD` |

## Validation Rules

Entries are validated before being sent to Salesforce:

- **Amount must be positive** - Entries with negative amounts are rejected
- Rejected entries are written to a `rejected.csv` file on the SFTP server containing their transaction IDs

## Idempotency

The `rest_service` ensures idempotent processing through two mechanisms:

### 1. Processing State File

A local JSON state file (`/tmp/processing_state.json`) tracks every transaction by its `transactionId` with one of three states:

| State | Meaning |
|-------|---------|
| `pending` | Validated but not yet confirmed in Salesforce |
| `success` | Successfully upserted to Salesforce |
| `rejected` | Failed validation (e.g., negative amount) |

On each run, the service:
1. Loads the state file at startup
2. **Skips** any transaction already marked `success` — prevents duplicate Salesforce upserts
3. **Re-validates** rejected entries (in case the CSV was corrected)
4. Persists updated state after processing

This means calling `POST /process` with the same CSV file multiple times is safe — already-processed donations will not be duplicated in Salesforce.

**To re-process all entries from scratch**, delete the state file:
```bash
rm /tmp/processing_state.json
```

### 2. Salesforce Upsert with External ID

The Bulk API v2 operation uses `upsert` with `Transaction_Id__c` as the external ID field. This means:
- If a `Donation__c` record with the same `Transaction_Id__c` already exists, it is **updated** (not duplicated)
- If no matching record exists, a new one is **inserted**

This provides a second layer of idempotency at the Salesforce level, even if the local state file is deleted.

## Prerequisites

- [Ballerina Swan Lake](https://ballerina.io/downloads/) (2201.13.5 or later)
- Salesforce Developer Org with:
  - `Donation__c` custom object with the fields listed above
  - Change Data Capture enabled for `Donation__c`
  - Connected App with OAuth2 credentials
- Gmail API OAuth2 credentials (for email notifications)
- SFTP server access (for CSV file hosting)
- Aiven Kafka cluster with SSL certificates (for message broker)

## Packages

### 1. rest_service

REST API that reads a donation CSV from SFTP, validates entries, and upserts valid records to Salesforce.

**Endpoint:**
```
POST http://localhost:9090/process
Content-Type: application/json

{
  "fileName": "donations.csv"
}
```

**Response:**
```json
{
  "fileName": "donations.csv",
  "validEntries": [
    {
      "transactionId": "TXN-2001",
      "donorId": "DON-2001",
      "donorName": "Sakura Tanaka",
      "donorEmail": "sakura.tanaka@example.jp",
      "amount": 250.00,
      "paymentMode": "CARD",
      "donationDate": "15/09/2026"
    }
  ]
}
```

**Config (`rest_service/Config.toml`):**
```toml
ftpHost = "<sftp-host>"
ftpPort = 22
ftpUsername = "<username>"
ftpPassword = "<password>"
protocol = "sftp"

clientId = "<salesforce-client-id>"
clientSecret = "<salesforce-client-secret>"
refreshToken = "<salesforce-refresh-token>"
refreshUrl = "https://login.salesforce.com/services/oauth2/token"
sfBaseUrl = "https://<your-org>.my.salesforce.com"
```

### 2. sf_trigger_email

Listens to Salesforce CDC events on `Donation__c` and sends a thank-you email to the donor via Gmail.

**What it does:**
1. Subscribes to `/data/Donation__ChangeEvent` via Salesforce Pub/Sub API
2. Extracts donor name, email, and amount from the CDC event
3. Renders a FreeMarker-style email template with `${placeholder}` substitution
4. Sends the email via the Google Gmail API

**Note:** CDC events only contain fields that were changed, not the full record. The email template uses only `donorName`, `donorEmail`, and `amount` which are reliably present in create/update events.

**Config (`sf_trigger_email/Config.toml`):**
```toml
instanceUrl = "https://<your-org>.my.salesforce.com"
tenantId = "<salesforce-org-id>"
clientId = "<salesforce-client-id>"
clientSecret = "<salesforce-client-secret>"
refreshToken = "<salesforce-refresh-token>"
refreshUrl = "https://login.salesforce.com/services/oauth2/token"

gmailClientId = "<google-client-id>"
gmailClientSecret = "<google-client-secret>"
gmailRefreshToken = "<google-refresh-token>"
```

### 3. sf_trigger_message_broker

Listens to the same Salesforce CDC events and publishes donation records to a Kafka topic.

**What it does:**
1. Subscribes to `/data/Donation__ChangeEvent` via Salesforce Pub/Sub API
2. Extracts donation data from the CDC event
3. Publishes the record as JSON to the `donations` Kafka topic over SSL/TLS

**Config (`sf_trigger_message_broker/Config.toml`):**
```toml
instanceUrl = "https://<your-org>.my.salesforce.com"
tenantId = "<salesforce-org-id>"
clientId = "<salesforce-client-id>"
clientSecret = "<salesforce-client-secret>"
refreshToken = "<salesforce-refresh-token>"
refreshUrl = "https://login.salesforce.com/services/oauth2/token"

kafkaBootstrapServers = "<kafka-host>:<port>"
kafkaCertPath = "resources/service.cert"
kafkaKeyPath = "resources/service.key"
kafkaCaCertPath = "resources/ca.pem"
```

**SSL certificates:** Place `service.cert`, `service.key`, and the CA `.pem` file in `sf_trigger_message_broker/resources/`.

## Running the Integrations

### Build all packages

```bash
bal build
```

### Run each package individually

```bash
# Terminal 1 - REST service
bal run rest_service

# Terminal 2 - Email notification trigger
bal run sf_trigger_email

# Terminal 3 - Kafka message broker trigger
bal run sf_trigger_message_broker
```

## Testing the Flow

### 1. Upload a CSV to SFTP

```bash
sshpass -p '<password>' sftp -P 22 -oStrictHostKeyChecking=no <username>@<sftp-host> <<'EOF'
put donations.csv donations.csv
bye
EOF
```

### 2. Trigger processing via REST API

```bash
curl -X POST http://localhost:9090/process \
  -H "Content-Type: application/json" \
  -d '{"fileName": "donations.csv"}'
```

This upserts donations to Salesforce, which fires CDC events picked up by the two triggers.

### 3. Verify Kafka messages

```bash
kcat -C -b <kafka-host>:<port> -X security.protocol=ssl -X ssl.ca.location=<ca.pem> -X ssl.certificate.location=<service.cert> -X ssl.key.location=<service.key> -t donations -e
```

### 4. Check email

The donor email addresses in the CSV will receive thank-you emails via Gmail.
