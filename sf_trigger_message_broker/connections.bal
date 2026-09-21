import ballerinax/kafka;

final kafka:Producer kafkaProducer = check new (string `${kafkaBootstrapServers}`, secureSocket = {
    cert: kafkaCaCertPath,
    key: {
        certFile: kafkaCertPath,
        keyFile: kafkaKeyPath
    }
}, securityProtocol = "SSL");
