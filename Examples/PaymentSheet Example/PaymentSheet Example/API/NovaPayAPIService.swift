import Foundation
import NovaPaySDKFramework

enum NovaPayAPIEnvironmentType: CaseIterable {
    case dev
    case staging
    
    var baseURL: String {
        switch self {
        case .dev:
            return "https://int-api-qecom.novapay.ua"
        case .staging:
            return "https://int-api-qecom.novapay.ua"
        }
    }
}

// MARK: - API Service
class NovaPayAPIService {
    static let shared = NovaPayAPIService()

    private var baseURL = NovaPayAPIEnvironmentType.dev.baseURL
    private let token = "lolkekcheburek"
    
    private init() {}
    
    @MainActor public func configure(with environment: NPEnvironmentType = .dev) {
        switch environment {
        case .dev:
            baseURL = NovaPayAPIEnvironmentType.dev.baseURL
        case .staging:
            baseURL = NovaPayAPIEnvironmentType.staging.baseURL
        default:
            baseURL = NovaPayAPIEnvironmentType.dev.baseURL
        }
    }
    
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
        try await sessionService.startPolling(sessionId: sessionId, completion: completion)
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

extension NovaPayAPIService {
    // Initialize payout
    func initializePayout(payoutRequest: PayoutInitRequest) async throws -> PayoutInitResponse {
        guard let url = URL(string: "\(baseURL)/v1/init-payout") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-type")
        request.addValue(token, forHTTPHeaderField: "x-token")
        
        let jsonData = try JSONEncoder().encode(payoutRequest)
        request.httpBody = jsonData

        let (data, _) = try await URLSession.shared.data(for: request)
        let string = String(data: data, encoding: .utf8)!
        print(string)
        return try JSONDecoder().decode(PayoutInitResponse.self, from: data)
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
