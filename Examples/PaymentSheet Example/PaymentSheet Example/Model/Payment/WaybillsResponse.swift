import Foundation

public struct WaybillsResponse: Decodable {
    let id = UUID()
    let client_first_name: String
    let client_last_name: String
    let client_patronymic: String
    let client_phone: String
    let client_email: String
    let metadata: PaymentMetadata
    let delivery_metadata: DeliveryMetadata
    let recipients: [Recipient]

    func totalAmount() -> Double {
        return recipients.reduce(0) { result, recipient in
            let amount = Double(recipient.amount ?? "0") ?? 0
            return result + amount
        }
    }
}
