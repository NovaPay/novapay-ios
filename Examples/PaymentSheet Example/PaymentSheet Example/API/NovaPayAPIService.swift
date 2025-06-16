import Foundation
import NovaPaySDKFramework

// MARK: - API Service
class NovaPayAPIService {
    static let shared = NovaPayAPIService()

    private let baseURL = "https://a2-sdk-internal-api.novapay.ua"
    private let token = "lolkekcheburek"
    
    private init() {}
    
    // Fetch waybills from API
    func fetchWaybills(phoneNumber: String) async throws -> [WaybillsResponse] {
        guard let encodedPhone = phoneNumber.addingPercentEncoding(withAllowedCharacters: .allowedCharacters) else {
            throw APIError.invalidPhoneFormat
        }
        
        guard let url = URL(string: "\(baseURL)/v1/express-waybills?phone=\(encodedPhone)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-type")
        request.addValue(token, forHTTPHeaderField: "x-token")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([WaybillsResponse].self, from: data)
    }
    
    // Initialize payment for a waybill
    func initializePayment(paymentRequest: PaymentInitRequest) async throws -> PaymentInitResponse {
        guard let url = URL(string: "\(baseURL)/v1/init") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-type")
        request.addValue(token, forHTTPHeaderField: "x-token")
        
        let jsonData = try JSONEncoder().encode(paymentRequest)
        request.httpBody = jsonData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(PaymentInitResponse.self, from: data)
    }

    // Monitor session status
    func startPolling(sessionId: String, completion: @escaping @Sendable (PaymentSheetResult) -> Void) async throws {
        let sessionService = NPSessionStatusService()
        await try sessionService.startPolling(sessionId: sessionId, completion: completion)
    }

    func stopPolling() async {
        let sessionService = NPSessionStatusService()
        await sessionService.stopPolling()
    }
}

extension NovaPayAPIService {
    // Initialize wallet
    func initializeWallet(walletRequest: WalletInitRequest) async throws -> WalletInitResponse {
        guard let url = URL(string: "\(baseURL)/v1/init-wallet-management") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-type")
        request.addValue(token, forHTTPHeaderField: "x-token")
        
        let jsonData = try JSONEncoder().encode(walletRequest)
        request.httpBody = jsonData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let string = String(data: data, encoding: .utf8)!
        print(string)
        return try JSONDecoder().decode(WalletInitResponse.self, from: data)
    }
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidPhoneFormat
    case invalidURL
    case noDataReceived
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPhoneFormat:
            return "Invalid phone number format"
        case .invalidURL:
            return "Invalid URL"
        case .noDataReceived:
            return "No data received"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        }
    }
}
