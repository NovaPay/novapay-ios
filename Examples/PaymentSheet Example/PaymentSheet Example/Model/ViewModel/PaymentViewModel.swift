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

    private var sessionId: String?
    private let apiService = NovaPayAPIService.shared
    
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
                    sessionId: response.session_id,
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
                token: token,
                walletSheetStatusHandler: walletStatusHandler
            )
            self.walletSheet = walletSheet
            isPresentedWallet = true
            isLoading = false
        } catch {
            isLoading = false
            showError(error.localizedDescription)
        }
    }

    // Wallet status handler
    func walletStatusHandler(result: WalletSheetResult) {
        switch result {
        case .canceled:
            isPresentedWallet = false
            self.walletSheet = nil
            print("Canceled!")
        case .undefined:
            isPresentedWallet = false
            self.walletSheet = nil
        case .failed(let error):
            isPresentedWallet = false
            self.walletSheet?.dismiss(completion: {
                self.walletSheet = nil
                self.showError(error)
            })
        case .removeCard:
            break
        case .favouriteCardChanged:
            break
        case .mainCardChanged:
            break
        case .addCard:
            break
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
            self.paymentSheet?.dismiss(completion: {
                self.payoutSheet = nil
                self.showError(error)
            })
        case .success:
            isPresentedPayout = false
            self.payoutSheet = nil
            print("PayoutCardChanged!")
        }
    }


    // Prepare payment sheet
    func preparePaymentSheet(
        sessionId: String,
        environment: NPEnvironmentType
    ) async {
        if sessionId.isEmpty {
            return
        }
        
        self.sessionId = sessionId
        do {
            let paymentSheet = try await PaymentSheet(
                sessionId: sessionId,
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
    func onDispose(result: PaymentSheetResult) {
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
                self.paymentSheet?.dismiss()
                finishPaymentSheet()
        }
    }

    func errorHandler(errorMessage: String) {
        self.paymentSheet?.dismiss()
        finishPaymentSheet()
        self.showError(errorMessage)
    }
    
    // Close payment sheet
    private func finishPaymentSheet() {
        isPresentedPaymentSheet = false
    }
    
    // Poll for payment status
    func startPolling() {
        guard let sessionId = sessionId else { return }
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
        self.isLoading = false
        self.errorMessage = message
        self.showErrorAlert = true
    }
}

// MARK: - Extensions
extension CharacterSet {
    static let allowedCharacters = urlQueryAllowed.subtracting(.init(charactersIn: "+"))
}
