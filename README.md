# NovaPay iOS SDK

A powerful and secure payment processing SDK for iOS applications that enables seamless integration of various payment methods.

## 📦 Installation

### Swift Package Manager (Recommended)

1. In Xcode, go to File > Add Packages
2. Enter the repository URL: `https://github.com/your-org/novapay-ios-sdk.git`
3. Select the version you want to use
4. Click Add Package

### Manual Integration

1. Clone the repository
2. Add `NovaPaySDKFramework.xcodeproj` to your project
3. In your target's Build Phases, add the framework to "Link Binary With Libraries"
4. Import the framework in your Swift files:
```swift
import NovaPaySDK
```

## 🚀 Getting Started

### Initialization

Initialize the SDK in your `AppDelegate` or `SceneDelegate`:

```swift
import NovaPaySDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Initialize SDK
        NPAPIClient.shared.configure(
            environment: .dev, // Options: dev, staging, production . By default dev
            languageType: .uk, Options: uk, en . By default uk
        )

        return true
    }
}
```

## 💳 Features

### Payment Sheet 

#### UIKit Implementation

The SDK provides a ready-to-use payment sheet that handles the complete payment flow. Here's a complete example:
```swift
import NovaPaySDKFramework

class PaymentViewController: UIViewController {
    
    // MARK: - Properties
    private var paymentSheet: PaymentSheet?
    private var sessionIds: [String] = []
    private let merchantIdentifier: String
    private let payButton = UIButton()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .white
        
        // Configure payment button
        payButton.setTitle("Pay Now", for: .normal)
        payButton.backgroundColor = .systemBlue
        payButton.setTitleColor(.white, for: .normal)
        payButton.layer.cornerRadius = 8
        payButton.addTarget(self, action: #selector(payButtonTapped), for: .touchUpInside)
        payButton.isEnabled = false
        payButton.setTitle("Loading...", for: .normal)
    }
    
    // MARK: - Payment Setup
    func initializePayment(
        waybills: [WaybillsResponse],
        environment: NPEnvironmentType
    ) {
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
                    environment: environment
                )
            } catch {
                self.handleError(error)
            }
        }
    }

    func preparePaymentSheet(
        sessionIds: [String],
        environment: NPEnvironmentType
    ) async {
        if sessionIds.isEmpty {
            return
        }

        self.sessionIds = sessionIds

        do {
            // Initialize the payment sheet
            self.paymentSheet = try await PaymentSheet(
                sessionIds: sessionIds,
                merchantIdentifier: merchantIdentifier
            )

            // Enable the button when payment sheet is ready
            self.payButton.isEnabled = true
            self.payButton.setTitle("Pay Now", for: .normal)
        } catch {
            self.handleError(error)
        }
    }
    
    // MARK: - Actions
    @objc private func payButtonTapped() {
        guard let paymentSheet = paymentSheet else {
            print("Payment sheet not initialized")
            return
        }

        // Present the payment sheet
        paymentSheet.present(
            from: self,
            paymentSheetStatus: handlePaymentSheetStatus,
            on3DsRequired: handleOn3DsRequired
        )
    }

    // MARK: - Callbacks
    private func handlePaymentSheetStatus(
        sessionId: String?,
        orderNumber: String?,
        result: PaymentSheetResult
    ) {
        switch result {
        case .canceled:
            dismissSheetAndFinish()
            print("Canceled!")
        case .undefined:
            dismissSheetAndFinish()
            print("Undefined!")
        case .failed(let errorMessage):
            errorHandler(errorMessage: errorMessage)
        case .completed:
            print("Completed!")
            dismissSheetAndFinish()
        }
    }
    
    private func handleOn3DsRequired() {
        paymentSheet?.show3DsScreen()
    }

    private func dismissSheetAndFinish(completion: @escaping () -> Void = {}) {
        paymentSheet?.dismiss(animated: true) {
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    private func errorHandler(errorMessage: String) {
        dismissSheetAndFinish {
            self.showAlert(title: "Payment Failed", message: errorMessage)
        }
    }
    
    private func handleError(_ error: Error) {
        payButton.isEnabled = false
        payButton.setTitle("Error", for: .normal)
        showAlert(title: "Error", message: "Failed to initialize payment: \(error.localizedDescription)")
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

#### SwiftUI Implementation

```swift
import SwiftUI
import NovaPaySDKFramework

struct PaymentView: View {
    @StateObject private var paymentModel = PaymentModel()
    
    var body: some View {
        VStack {
            if paymentModel.isLoading {
                ProgressView("Preparing payment...")
            } else {
                // Standard button approach
                Button("Pay with Standard Button") {
                    paymentModel.initializePayment(
                        waybills: paymentModel.waybills,
                        environment: .dev
                    )
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                // PaymentButton convenience wrapper approach
                if let paymentSheet = paymentModel.paymentSheet {
                    PaymentSheet.PaymentButton(
                        paymentSheet: paymentSheet,
                        paymentSheetStatus: paymentModel.onDispose,
                        on3DsRequired: paymentModel.handleOn3DsRequired
                    ) {
                        Text("Pay")
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top, 20)
                }
                
                // When payment sheet should be presented
                if let paymentSheet = paymentModel.paymentSheet {
                    EmptyView()
                        .paymentSheet(
                            isPresented: $paymentModel.isPresentedPaymentSheet,
                            paymentSheet: paymentSheet,
                            paymentSheetStatus: paymentModel.onDispose,
                            on3DsRequired: paymentModel.handleOn3DsRequired
                        )
                }
            }
        }
        .padding()
        .alert(isPresented: $paymentModel.showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(paymentModel.errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

class PaymentModel: ObservableObject {
    @Published var paymentSheet: PaymentSheet?
    @Published var isPresentedPaymentSheet = false
    @Published var isLoading = false
    @Published var showErrorAlert = false
    @Published var errorMessage: String?

    var sessionIds: [String]?
    var waybills: [WaybillsResponse] = []
    
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
                    environment: environment
                )
            } catch {
                showError(error.localizedDescription)
            }
        }
    }
    
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

            await MainActor.run {
                self.paymentSheet = paymentSheet
                self.isPresentedPaymentSheet = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.showError(error.localizedDescription)
            }
        }
    }
    
    func onDispose(
        sessionId: String?,
        orderNumber: String?,
        result: PaymentSheetResult
    ) {
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
        dismissSheetAndFinish {
            self.showError(errorMessage)
        }
    }

    // Close payment sheet
    private func finishPaymentSheet() {
        isPresentedPaymentSheet = false
    }
    
    func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
        isLoading = false
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
}
```

### Payment Status Handling

The SDK provides callbacks to handle different payment statuses:
Session Status Types
```swift
enum NPSessionStatusType {
    case preprocessing // Payment is being prepared
    case processing    // Payment is being processed
    case holded        // Payment is on hold
    case voided        // Payment was voided
    case paid          // Payment was successful
    case failed        // Payment failed
}
```

#### Payment Sheet Status Types

```swift
@frozen public enum PaymentSheetResult {
    case undefined // Payment sheet was closed with undefined status
    case canceled  // User canceled the payment
    case failed(String)
    case completed(NPSessionStatusType?)
}
```

#### Advanced Usage
Polling for Payment Status
For payments that require additional processing time, you can implement polling:

```swift
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
```

### Supported Payment Methods

- 💳 Manual card payments
- 👛 Wallet card
- 🍎 Apple Pay

### Session Management

Check the status of a payment session:

```swift
NovaPay.getSession(sessionId: "your_session_id") { result in
    switch result {
    case .success(let status):
        print("Session status: \(status)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

### 💳 Wallet Sheet 

The WalletSheet provides a comprehensive interface for managing saved payment cards, allowing users to add, remove, and manage their favorite payment methods.

#### UIKit Implementation

```swift
import NovaPaySDKFramework

class WalletViewController: UIViewController {
    
    // MARK: - Properties
    private var walletSheet: WalletSheet?
    private let token: String
    private let walletButton = UIButton()
    
    init(token: String) {
        self.token = token
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupWalletSheet()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .white
        
        // Configure wallet button
        walletButton.setTitle("Manage Cards", for: .normal)
        walletButton.backgroundColor = .systemGreen
        walletButton.setTitleColor(.white, for: .normal)
        walletButton.layer.cornerRadius = 8
        walletButton.addTarget(self, action: #selector(walletButtonTapped), for: .touchUpInside)
        
        // Add constraints (implementation depends on your layout approach)
        view.addSubview(walletButton)
        // Add your constraints here
    }
    
    // MARK: - Wallet Setup
    private func setupWalletSheet() {
        // Disable the button until wallet sheet is ready
        walletButton.isEnabled = false
        walletButton.setTitle("Loading...", for: .normal)

        Task {
            do {
                // Initialize the wallet sheet
                self.walletSheet = try await WalletSheet(
                    token: token
                )

                // Enable the button when wallet sheet is ready
                await MainActor.run {
                    self.walletButton.isEnabled = true
                    self.walletButton.setTitle("Manage Cards", for: .normal)
                }
            } catch {
                await MainActor.run {
                    self.handleError(error)
                }
            }
        }
    }
    
    // MARK: - Actions
    @objc private func walletButtonTapped() {
        guard let walletSheet = walletSheet else {
            print("Wallet sheet not initialized")
            return
        }
        
        // Present the wallet sheet
        walletSheet.present(
            from: self
        )
    }

    private func handleError(_ error: Error) {
        walletButton.isEnabled = false
        walletButton.setTitle("Error", for: .normal)
        showAlert(title: "Error", message: "Failed to initialize wallet: \(error.localizedDescription)")
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

#### SwiftUI Implementation

```swift
import SwiftUI
import NovaPaySDKFramework

struct WalletView: View {
    @StateObject private var walletModel = WalletModel()
    
    var body: some View {
        VStack {
            if walletModel.isLoading {
                ProgressView("Loading wallet...")
            } else {
                // Standard button approach
                Button("Manage Cards") {
                    walletModel.isPresentedWalletSheet = true
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                // WalletSheet PaymentButton convenience wrapper approach
                if let walletSheet = walletModel.walletSheet {
                    WalletSheet.PaymentButton(
                        walletSheet: walletSheet
                    ) {
                        Text("Wallet")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top, 20)
                }
                
                // When wallet sheet should be presented
                if let walletSheet = walletModel.walletSheet {
                    EmptyView()
                        .walletSheet(
                            isPresented: $walletModel.isPresentedWalletSheet,
                            walletSheet: walletSheet
                        )
                }
            }
        }
        .padding()
        .alert(isPresented: $walletModel.showError) {
            Alert(
                title: Text("Error"),
                message: Text(walletModel.errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            walletModel.initializeWalletSheet()
        }
    }
}

class WalletModel: ObservableObject {
    @Published var walletSheet: WalletSheet?
    @Published var isPresentedWalletSheet = false
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let token: String
    
    init(token: String = "your_auth_token_here") {
        self.token = token
    }
    
    func initializeWalletSheet() {
        isLoading = true
        
        Task {
            do {
                let sheet = try await WalletSheet(
                    token: token
                )

                await MainActor.run {
                    self.walletSheet = sheet
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.showError(message: error.localizedDescription)
                }
            }
        }
    }
    
    func handleWalletSheetStatus(_ result: WalletSheetResult) {
        switch result {
        case .addCard(let card):
            print("Card added: \(card)")
            dismissWalletSheet()
        case .removeCard:
            print("Card removed")
            dismissWalletSheet()
        case .favouriteCardChanged(let cardId, let isFavourite):
            print("Favourite card changed - ID: \(cardId ?? -1), isFavourite: \(isFavourite ?? false)")
        case .mainCardChanged(let cardId, let isMain):
            print("Main card changed - ID: \(cardId ?? -1), isMain: \(isMain ?? false)")
        case .canceled:
            dismissWalletSheet()
            print("Wallet management canceled!")
        case .failed(let errorMessage):
            showError(message: errorMessage)
            dismissWalletSheet()
        case .undefined:
            dismissWalletSheet()
            print("Wallet status undefined!")
        }
    }
    
    func handleSessionStatus(_ status: NPSessionStatusType) {
        // Handle session status if needed
        switch status {
        case .completed:
            print("Session completed")
        case .failed:
            print("Session failed")
        default:
            break
        }
    }
    
    private func dismissWalletSheet() {
        walletSheet?.dismiss()
        isPresentedWalletSheet = false
    }
    
    func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
```

#### Authentication Requirements

The WalletSheet requires authentication via a token. Ensure you have a valid authentication token before initializing:

```swift
// Get authentication token from your backend
func getAuthToken(completion: @escaping (Result<String, Error>) -> Void) {
    // Implement your authentication logic here
    // This should call your backend API to get a valid token
}

// Then use it to initialize WalletSheet
getAuthToken { result in
    switch result {
    case .success(let token):
        Task {
            do {
                let walletSheet = try await WalletSheet(token: token)
                // Use wallet sheet
            } catch {
                print("Failed to initialize wallet sheet: \(error)")
            }
        }
    case .failure(let error):
        print("Failed to get auth token: \(error)")
    }
}
```

#### Card Management Features

The WalletSheet provides comprehensive card management capabilities:

- **Add New Cards**: Users can add new payment cards to their wallet
- **Remove Cards**: Users can remove existing cards from their wallet
- **Set Favourite Cards**: Users can mark cards as favourites for quick access
- **Set Main Card**: Users can designate a primary card for default payments
- **View Card Details**: Users can view their saved card information

### 🧾 Payout Sheet

The `PayoutSheet` is a drop-in solution to present a customizable payout flow for transferring or withdrawing funds.

#### SwiftUI Implementation

```swift
import SwiftUI
import NovaPaySDKFramework

struct PayoutView: View {
    @State private var payoutSheet: PayoutSheet?
    @State private var isPresented = false

    var body: some View {
        VStack {
            if let payoutSheet = payoutSheet {
                PayoutSheet.PaymentButton(
                    payoutSheet: payoutSheet,
                    payoutSheetStatusHandler: handlePayoutStatus
                ) {
                    Text("Withdraw Funds")
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                // Alternatively, use the ViewModifier directly
                EmptyView()
                    .payoutSheet(
                        isPresented: $isPresented,
                        payoutSheet: payoutSheet,
                        payoutSheetStatusHandler: handlePayoutStatus
                    )
            } else {
                ProgressView("Preparing payout...")
            }
        }
        .onAppear {
            Task {
                do {
                    let sheet = try await PayoutSheet(
                        sessionId: "your_session_id"
                    )
                    self.payoutSheet = sheet
                } catch {
                    print("Failed to initialize payout sheet: \(error)")
                }
            }
        }
    }

    func handlePayoutStatus(_ result: PayoutSheetResult) {
        switch result {
        case .success:
            print("Payout completed!")
        case .canceled:
            print("Payout canceled")
        case .failed(let error):
            print("Payout failed: \(error)")
        case .undefined:
            print("Payout status undefined")
        }
    }
}
```

#### UIKit Implementation

```swift
import NovaPaySDKFramework

class PayoutViewController: UIViewController {

    private var payoutSheet: PayoutSheet?
    private let sessionId: String
    private let payoutButton = UIButton()

    init(sessionId: String) {
        self.sessionId = sessionId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupButton()
        setupPayoutSheet()
    }

    private func setupButton() {
        payoutButton.setTitle("Withdraw", for: .normal)
        payoutButton.backgroundColor = .systemPurple
        payoutButton.setTitleColor(.white, for: .normal)
        payoutButton.layer.cornerRadius = 8
        payoutButton.addTarget(self, action: #selector(payoutButtonTapped), for: .touchUpInside)
        payoutButton.isEnabled = false
        view.addSubview(payoutButton)
        // Add layout constraints here
    }

    private func setupPayoutSheet() {
        Task {
            do {
                let sheet = try await PayoutSheet(sessionId: sessionId)
                self.payoutSheet = sheet
                DispatchQueue.main.async {
                    self.payoutButton.isEnabled = true
                }
            } catch {
                print("Failed to initialize payout sheet: \(error)")
            }
        }
    }

    @objc private func payoutButtonTapped() {
        guard let sheet = payoutSheet else { return }
        sheet.present(from: self) { result in
            switch result {
            case .success:
                print("Payout completed")
            case .canceled:
                print("Payout canceled")
            case .failed(let message):
                print("Payout failed: \(message)")
            case .undefined:
                print("Payout status undefined")
            }
        }
    }
}
```

#### Result Types

```swift
@frozen public enum PayoutSheetResult {
    case undefined
    case canceled
    case failed(String)
    case success
}
```

#### Integration Highlights

- ✅ SwiftUI + UIKit support
- ✅ `.payoutSheet` ViewModifier and `PaymentButton` view
- ✅ Built-in error handling and async-ready


## 📱 Example Project

The SDK includes a complete example project in the `Examples/PaymentSheet Example` directory. To run the example:

1. Open `NovaPaySDKFramework.xcodeproj`
2. Select the "PaymentSheet Example" target
3. Run the project

The example demonstrates:
- SDK initialization
- Payment sheet integration
- Session management
- Error handling
- UI customization

## ⚙️ Requirements

- iOS 13.0+
- Xcode 12.0+
- Swift 5.0+
- Internet permission in Info.plist:
    ```xml
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    ```

## 🌍 Environment Configuration

| Environment | Description |
|------------|-------------|
| `development` | Development and testing environment |
| `staging` | Pre-production testing environment |
| `production` | Production environment |

## 🔒 Security Features

- Secure handling of sensitive payment information
- HTTPS communication
- Optional card details storage
- Comprehensive error handling through status callbacks

## 📞 Support

For technical support or questions, please contact NovaPay support team.

## 📄 License

This SDK is proprietary software. Usage terms and conditions are defined in your license agreement.

---

For detailed implementation examples and advanced features, please refer to the example app included in the SDK package. 
