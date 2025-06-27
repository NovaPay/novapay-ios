import Foundation

// Models for payment initialization
struct PayoutInitRequest: Encodable {
    let phone: String
    let external_id: String
    let metadata: PaymentMetadata
}
