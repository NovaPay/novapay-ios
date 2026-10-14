import Foundation
import SwiftUI
import NovaPaySDKFramework

@MainActor
class PaymentViewModel: ObservableObject {
    @Published var paymentSheet: PaymentSheet?
    @Published var walletSheet: WalletSheet?
    @Published var payoutSheet: PayoutSheet?
    @Published var isPresentedPaymentSheet: Bool = false
    @Published var isPresentedWallet: Bool = false
    @Published var isPresentedPayout: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false
    @Published var waybills: [WaybillsResponse] = []
    @Published private(set) var selectedEnvironment: NPEnvironmentType = .staging
    @Published private(set) var selectedAPIServiceEnvironment: NovaPayAPIEnvironmentType = .staging

    private var sessionIds: [String]?
    public let apiService = NovaPayAPIService.shared

    private enum StorageKey {
        static let environment = "savedEnvironment"
        static let apiServiceEnvironment = "savedAPIServiceEnvironment"
    }

    init() {
        restoreEnvironment()
        restoreAPIServiceEnvironment()
    }

    // MARK: - Environment

    var environmentBinding: Binding<NPEnvironmentType> {
        Binding(
            get: { [weak self] in self?.selectedEnvironment ?? .staging },
            set: { [weak self] in self?.selectEnvironment($0) }
        )
    }

    var apiServiceEnvironmentBinding: Binding<NovaPayAPIEnvironmentType> {
        Binding(
            get: { [weak self] in self?.selectedAPIServiceEnvironment ?? .staging },
            set: { [weak self] in self?.selectAPIServiceEnvironment($0) }
        )
    }

    func selectEnvironment(_ environment: NPEnvironmentType) {
        do {
            try NPAPIClient.shared.configure(with: environment)
            selectedEnvironment = environment
            UserDefaults.standard.set(environment.identifier, forKey: StorageKey.environment)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func selectAPIServiceEnvironment(_ environment: NovaPayAPIEnvironmentType) {
        do {
            try apiService.configure(with: environment)
            selectedAPIServiceEnvironment = environment
            UserDefaults.standard.set(environment.identifier, forKey: StorageKey.apiServiceEnvironment)
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func restoreEnvironment() {
        guard let saved = UserDefaults.standard.string(forKey: StorageKey.environment) else {
            selectEnvironment(.staging)
            return
        }
        guard let environment = NPEnvironmentType(identifier: saved) else {
            UserDefaults.standard.removeObject(forKey: StorageKey.environment)
            selectEnvironment(.staging)
            showError("Збережене середовище SDK «\(saved)» більше не підтримується. Обрано Staging.")
            return
        }
        selectEnvironment(environment)
    }

    private func restoreAPIServiceEnvironment() {
        guard let saved = UserDefaults.standard.string(forKey: StorageKey.apiServiceEnvironment) else {
            selectAPIServiceEnvironment(.staging)
            return
        }
        guard let environment = NovaPayAPIEnvironmentType(identifier: saved) else {
            UserDefaults.standard.removeObject(forKey: StorageKey.apiServiceEnvironment)
            selectAPIServiceEnvironment(.staging)
            showError("Збережене середовище API «\(saved)» більше не підтримується. Обрано Staging.")
            return
        }
        selectAPIServiceEnvironment(environment)
    }

    // MARK: - Waybills

    func fetchWaybills(phoneNumber: String) {
        isLoading = true

        Task {
            do {
                let fetchedWaybills = try await apiService.fetchWaybills(phoneNumber: phoneNumber)
                self.waybills = fetchedWaybills
                self.isLoading = false
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    // MARK: - Payment

    func initializePayment(waybill: WaybillsResponse) {
        initializePayment(waybills: [waybill])
    }

    func initializePayment(waybills: [WaybillsResponse]) {
        isLoading = true
        showErrorAlert = false

        Task {
            do {
                var collectedSessionIds: [String] = []
                for waybill in waybills {
                    let paymentRequest = PaymentInitRequest.convert(from: waybill)
                    let response = try await apiService.initializePayment(paymentRequest: paymentRequest)
                    collectedSessionIds.append(response.session_id)
                }
                await preparePaymentSheet(sessionIds: collectedSessionIds)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    func preparePaymentSheet(sessionIds: [String]) async {
        guard !sessionIds.isEmpty else {
            isLoading = false
            return
        }
        self.sessionIds = sessionIds
        do {
            let paymentSheet = try await PaymentSheet(
                sessionIds: sessionIds,
                merchantIdentifier: "merchant.ua.novapay.novapaymobile"
            )
            self.paymentSheet = paymentSheet
            self.isLoading = false
            self.isPresentedPaymentSheet = true
        } catch {
            isLoading = false
            showError(error.localizedDescription)
        }
    }

    func onDispose(sessionId: String?, orderNumber: String?, result: PaymentSheetResult) {
        switch result {
        case .canceled:
            finishPaymentSheet()
        case .undefined:
            self.paymentSheet?.dismiss()
            finishPaymentSheet()
        case .failed(let errorMessage):
            errorHandler(errorMessage: errorMessage)
        case .completed:
            finishPaymentSheet()
        }
    }

    func handleOn3DsRequired() {
        paymentSheet?.show3DsScreen()
    }

    func dismissSheetAndFinish(completion: @escaping () -> Void = {}) {
        self.paymentSheet?.dismiss(animated: true) { [weak self] in
            Task { @MainActor in
                self?.finishPaymentSheet()
                completion()
            }
        }
    }

    func errorHandler(errorMessage: String) {
        finishPaymentSheet()
        showError(errorMessage)
    }

    private func finishPaymentSheet() {
        isPresentedPaymentSheet = false
    }

    // MARK: - Wallet

    func initializeWallet(phone: String, clientVerified: Bool = true) {
        isLoading = true

        Task {
            do {
                let walletRequest = WalletInitRequest(phone: phone, client_verified: clientVerified)
                let response = try await apiService.initializeWallet(walletRequest: walletRequest)
                showWalletSheet(token: response.token)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    func showWalletSheet(token: String) {
        self.walletSheet = WalletSheet(token: token)
        self.isLoading = false
        self.isPresentedWallet = true
    }

    func onDisposeWallet() {
        isPresentedWallet = false
        walletSheet = nil
    }

    func onWalletLoadError(_ error: Error) {
        isPresentedWallet = false
        walletSheet = nil
        showError(error.localizedDescription)
    }

    // MARK: - Payout

    func initializePayout(phone: String) {
        isLoading = true

        Task {
            do {
                let uuid = UUID().uuidString
                let metadata = PaymentMetadata(
                    payer_type: "",
                    source: "",
                    client_verified: true,
                    client_npuid: "",
                    ref_settlement_recipient: "",
                    ref_settlement_sender: ""
                )
                let payoutRequest = PayoutInitRequest(phone: phone, external_id: uuid, metadata: metadata)
                let response = try await apiService.initializePayout(payoutRequest: payoutRequest)
                showPayoutSheet(sessionId: response.id)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    func showPayoutSheet(sessionId: String) {
        self.payoutSheet = PayoutSheet(
            sessionId: sessionId,
            payoutSheetStatusHandler: onDisposePayout
        )
        self.isLoading = false
        self.isPresentedPayout = true
    }

    func onDisposePayout(result: PayoutSheetResult) {
        isPresentedPayout = false

        switch result {
        case .canceled, .undefined:
            payoutSheet = nil
        case .failed(let error):
            payoutSheet?.dismiss { [weak self] in
                self?.payoutSheet = nil
                self?.showError(error)
            }
        case .success(let cardId, let pan):
            payoutSheet = nil
            print("Payout card saved: \(cardId) \(pan)")
        }
    }

    // MARK: - Polling

    func startPolling() {
        guard let sessionId = sessionIds?.first else { return }
        let sessionService = NPSessionStatusService()
        Task {
            try await sessionService.startPolling(sessionId: sessionId) { result in
                switch result {
                case .failed(let error):
                    print("Polling error: \(error)")
                case .completed(let status):
                    print("Polling status: \(String(describing: status))")
                default:
                    break
                }
            }
        }
    }

    // MARK: - Error handling

    func showError(_ message: String) {
        guard !showErrorAlert else { return }
        self.isLoading = false
        self.errorMessage = message
        self.showErrorAlert = true
    }
}

extension CharacterSet {
    static let allowedCharacters = urlQueryAllowed.subtracting(.init(charactersIn: "+"))
}
