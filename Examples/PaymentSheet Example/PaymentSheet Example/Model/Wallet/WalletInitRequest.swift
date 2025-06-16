import Foundation

// Models for payment initialization
struct WalletInitRequest: Encodable {
    let phone: String
    let client_verified: Bool
}

