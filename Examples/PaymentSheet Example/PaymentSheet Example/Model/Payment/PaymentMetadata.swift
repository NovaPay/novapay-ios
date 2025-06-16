public struct PaymentMetadata: Encodable, Decodable {
    let payer_type: String
    let source: String
    let client_verified: Bool
    let client_npuid: String
    let ref_settlement_recipient: String
    let ref_settlement_sender: String
}
