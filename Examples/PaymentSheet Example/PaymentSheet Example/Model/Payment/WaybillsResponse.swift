import Foundation

public struct WaybillsResponse: Decodable {
    let client_first_name: String
    let client_last_name: String
    let client_patronymic: String
    let client_phone: String
    let client_email: String
    let metadata: PaymentMetadata
    let delivery_metadata: DeliveryMetadata
    let recipients: [Recipient]

    let id = UUID()

    private enum CodingKeys: String, CodingKey {
        case client_first_name
        case client_last_name
        case client_patronymic
        case client_phone
        case client_email
        case metadata
        case delivery_metadata
        case recipients
    }

    func totalAmount() -> Double {
        recipients.reduce(0) { result, recipient in
            result + (Double(recipient.amount ?? "0") ?? 0)
        }
    }
}
