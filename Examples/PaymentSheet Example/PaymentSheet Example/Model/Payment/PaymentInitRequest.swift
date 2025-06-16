import Foundation

// Models for payment initialization
struct PaymentInitRequest: Encodable {
    let client_first_name: String
    let client_last_name: String
    let client_patronymic: String
    let client_phone: String
    let client_email: String
    let metadata: PaymentMetadata
    let delivery_metadata: DeliveryMetadata
    let recipients: [Recipient]
    
    
    static func convert(from: WaybillsResponse) -> PaymentInitRequest {
        let request = PaymentInitRequest(
            client_first_name: from.client_first_name,
            client_last_name: from.client_last_name,
            client_patronymic: from.client_patronymic,
            client_phone: from.client_phone,
            client_email: from.client_email,
            metadata: from.metadata,
            delivery_metadata: from.delivery_metadata,
            recipients: from.recipients
        )
        return request
    }
}

