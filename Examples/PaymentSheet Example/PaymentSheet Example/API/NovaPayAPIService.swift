import Foundation
import NovaPaySDKFramework

enum NovaPayAPIEnvironmentType: Hashable {
    case staging
    case development(String)

    private static let developmentPrefix = "development|"

    static let storageKey = "NovaPayAPIEnvironmentIdentifier"

    var baseURL: String {
        switch self {
        case .staging:
            return "https://int-api-qecom.novapay.ua"
        case .development(let url):
            return url
        }
    }

    var identifier: String {
        switch self {
        case .staging:
            return "staging"
        case .development(let url):
            return Self.developmentPrefix + url
        }
    }

    var title: String {
        switch self {
        case .staging: return "Staging"
        case .development: return "Development"
        }
    }

    init?(identifier: String) {
        if identifier == "staging" {
            self = .staging
        } else if identifier.hasPrefix(Self.developmentPrefix) {
            let urlString = String(identifier.dropFirst(Self.developmentPrefix.count))
            guard Self.isValidBaseURL(urlString) else { return nil }
            self = .development(urlString)
        } else {
            return nil
        }
    }

    static func isValidBaseURL(_ urlString: String) -> Bool {
        guard let components = URLComponents(string: urlString),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty
        else { return false }
        return true
    }

    var sdkEnvironment: NPEnvironmentType {
        switch self {
        case .staging: return .staging
        case .development(let url): return .development(url)
        }
    }
}

extension NovaPayAPIEnvironmentType {

    static func restore(
        from defaults: UserDefaults = .standard
    ) -> (environment: NovaPayAPIEnvironmentType, unreadableIdentifier: String?) {
        guard let saved = defaults.string(forKey: storageKey) else {
            return (.staging, nil)
        }
        guard let restored = NovaPayAPIEnvironmentType(identifier: saved) else {
            return (.staging, saved)
        }
        return (restored, nil)
    }

    func store(in defaults: UserDefaults = .standard) {
        defaults.set(identifier, forKey: Self.storageKey)
    }
}

class NovaPayAPIService {
    static let shared = NovaPayAPIService()

    private(set) var environment: NovaPayAPIEnvironmentType = .staging
    private var baseURL: String { environment.baseURL }
    private let token = "lolkekcheburek"

    private init() {}

    @MainActor public func configure(with environment: NovaPayAPIEnvironmentType = .staging) throws {
        guard NovaPayAPIEnvironmentType.isValidBaseURL(environment.baseURL) else {
            throw APIError.invalidEnvironmentURL(environment.baseURL)
        }
        try NPAPIClient.shared.configure(with: environment.sdkEnvironment)
        self.environment = environment
        environment.store()
    }

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

enum APIError: Error, LocalizedError {
    case invalidPhoneFormat
    case invalidURL
    case invalidEnvironmentURL(String)
    case unknownEnvironmentIdentifier(String)
    case noDataReceived
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidPhoneFormat:
            return "Invalid phone number format"
        case .invalidURL:
            return "Invalid URL"
        case .invalidEnvironmentURL(let urlString):
            return "Invalid environment URL: \(urlString)"
        case .unknownEnvironmentIdentifier(let identifier):
            return "Unknown environment identifier: \(identifier)"
        case .noDataReceived:
            return "No data received"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        }
    }
}
