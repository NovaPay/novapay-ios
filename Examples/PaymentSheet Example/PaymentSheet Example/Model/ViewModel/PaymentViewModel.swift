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
    @Published var errorMessage: String? = nil
    @Published var showErrorAlert: Bool = false
    @Published var waybills: [WaybillsResponse] = []

    private var sessionIds: [String]?
    public let apiService = NovaPayAPIService.shared

    init() {
        NPAPIClient.shared.configure(with: selectedEnvironment)
        apiService.configure(with: selectedAPIServiceEnvironment)
    }

    @Published var selectedEnvironment: NPEnvironmentType = {
        let saved = UserDefaults.standard.string(forKey: "savedEnvironment") ?? ""
        return NPEnvironmentType(identifier: saved) ?? .dev
    }() {
        didSet {
            UserDefaults.standard.set(selectedEnvironment.identifier, forKey: "savedEnvironment")
            NPAPIClient.shared.configure(with: selectedEnvironment)
        }
    }

    @Published var selectedAPIServiceEnvironment: NovaPayAPIEnvironmentType = {
        let saved = UserDefaults.standard.string(forKey: "savedAPIServiceEnvironment") ?? ""
        return NovaPayAPIEnvironmentType(identifier: saved) ?? .dev
    }() {
        didSet {
            UserDefaults.standard.set(selectedAPIServiceEnvironment.identifier, forKey: "savedAPIServiceEnvironment")
            apiService.configure(with: selectedAPIServiceEnvironment)
        }
    }

    // Fetch waybills
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

    // Initialize payment
    func initializePayment(
        waybill: WaybillsResponse,
        environment: NPEnvironmentType
    ) {
        isLoading = true

        Task {
            do {
                let paymentRequest = PaymentInitRequest.convert(from: waybill)
                let response = try await apiService.initializePayment(paymentRequest: paymentRequest)
                await preparePaymentSheet(
                    sessionIds: [response.session_id],
                    environment: environment)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    // Initialize payment
    func initializePayment(
        waybills: [WaybillsResponse],
        environment: NPEnvironmentType
    ) {
        isLoading = true
        showErrorAlert = false
        var sessionsIds: [String] = []
        Task {
            do {
                for waybill in waybills {
                    let paymentRequest = PaymentInitRequest.convert(from: waybill)
                    let response = try await apiService.initializePayment(paymentRequest: paymentRequest)
                    sessionsIds.append(response.session_id)
                }
                await preparePaymentSheet(
                    sessionIds: sessionsIds,
                    environment: environment)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    func initializeWallet(
        phone: String,
        clientVerified: Bool = true
    ) {
        isLoading = true

        Task {
            do {
                let walletRequest = WalletInitRequest(phone: phone, client_verified: clientVerified)
                let response = try await apiService.initializeWallet(walletRequest: walletRequest)
                await showWalletSheet(token: response.token)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    // Show wallet sheet
    func showWalletSheet(token: String) async {
        self.isPresentedWallet = true
        do {
            let walletSheet = try await WalletSheet(
                token: token
            )
            self.walletSheet = walletSheet
            isPresentedWallet = true
            isLoading = false
            
        } catch {
            isLoading = false
            self.isPresentedWallet = false
            showError(error.localizedDescription)
        }
    }

    // Show payout sheet

    func initializePayout(
        phone: String
    ) {
        isLoading = true
        Task {
            do {
                let uuid = UUID().uuidString
                let metadata = PaymentMetadata(payer_type: "", source: "", client_verified: true, client_npuid: "", ref_settlement_recipient: "", ref_settlement_sender: "")
                let payoutRequest = PayoutInitRequest(phone: phone, external_id: uuid, metadata: metadata)
                let response = try await apiService.initializePayout(payoutRequest: payoutRequest)
                await showPayoutSheet(sessionId: response.id)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    func showPayoutSheet(sessionId: String) async {
        self.isPresentedPayout = true
        do {
            let payoutSheet = try await PayoutSheet(
                sessionId: sessionId,
                payoutSheetStatusHandler: payoutStatusHandler
            )
            self.payoutSheet = payoutSheet
            isPresentedPayout = true
            isLoading = false
        } catch {
            isLoading = false
            self.isPresentedPayout = false
            showError(error.localizedDescription)
        }
    }

    // Payout status handler
    func payoutStatusHandler(result: PayoutSheetResult) {
        switch result {
        case .canceled:
            isPresentedPayout = false
            self.payoutSheet = nil
            print("Canceled!")
        case .undefined:
            isPresentedPayout = false
            self.payoutSheet = nil
        case .failed(let error):
            isPresentedPayout = false
            self.payoutSheet = nil
            showError(error)
        case .success:
            isPresentedPayout = false
            self.payoutSheet = nil
            print("PayoutCardChanged!")
        }
    }

    // Prepare payment sheet
    func preparePaymentSheet(
        sessionIds: [String],
        environment: NPEnvironmentType
    ) async {
        if sessionIds.isEmpty {
            return
        }
        self.sessionIds = sessionIds
        do {
            let paymentSheet = try await PaymentSheet(
                sessionIds: sessionIds,
                merchantIdentifier: "merchant.ua.novapay.novapaymobile"
            )
            self.paymentSheet = paymentSheet
            isPresentedPaymentSheet = true
            isLoading = false
        } catch {
            isLoading = false
            showError(error.localizedDescription)
        }
    }

    // Payment sheet status handler
    func onDispose(sessionId: String?, orderNumber: String?, result: PaymentSheetResult) {
        switch result {
            case .canceled:
                finishPaymentSheet()
                print("Canceled!")
            case .undefined:
                self.paymentSheet?.dismiss()
                finishPaymentSheet()
            case .failed(let errorMessage):
                errorHandler(errorMessage: errorMessage)
            case .completed:
                print("Completed!")
                finishPaymentSheet()
        }
    }

    // Wallet sheet dismiss handler (regular close, not an error)
    func onWalletDismiss() {
        dismissWalletSheet()
    }

    private func dismissWalletSheet() {
        isPresentedWallet = false
        walletSheet = nil
    }

    func handleOn3DsRequired() {
        paymentSheet?.show3DsScreen()
    }

    func dismissSheetAndFinish(completion: @escaping () -> Void = {}) {
        self.paymentSheet?.dismiss(animated: true) {
            DispatchQueue.main.async {
                self.finishPaymentSheet()
                completion()
            }
        }
    }

    func errorHandler(errorMessage: String) {
        finishPaymentSheet()
        self.showError(errorMessage)
    }

    // Close payment sheet
    private func finishPaymentSheet() {
        isPresentedPaymentSheet = false
    }
    
    // Poll for payment status
    func startPolling() {
        guard let sessionId = sessionIds?.first else { return }
        let sessionService = NPSessionStatusService()
        Task {
            try await sessionService.startPolling(sessionId: sessionId) { result in
                switch result {
                case .failed(let error):
                    print("Error: \(error)")
                case .completed(let status):
                    switch status {
                    case .preprocessing:
                        print("preprocessing")
                    case .processing:
                        print("processing")
                    case .holded:
                        print("holded")
                    case .voided:
                        print("voided")
                    case .failed:
                        print("failed")
                    default:
                        break
                    }
                default:
                    break
                }
            }
        }
    }

    // Error handling
    @MainActor
    func showError(_ message: String) {
        if (showErrorAlert == true) {
            return
        }
        self.isLoading = false
        self.errorMessage = message
        self.showErrorAlert = true
    }
}

// MARK: - Extensions
extension CharacterSet {
    static let allowedCharacters = urlQueryAllowed.subtracting(.init(charactersIn: "+"))
}
