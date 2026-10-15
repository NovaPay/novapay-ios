# NovaPay iOS SDK

A powerful and secure payment processing SDK for iOS applications that enables seamless integration of various payment methods.

## 📦 Installation

### Swift Package Manager (Recommended)

1. In Xcode, go to File > Add Packages
2. Enter the repository URL: `https://github.com/your-org/novapay-ios-sdk.git`
3. Select the version you want to use
4. Click Add Package

### Manual Integration

1. Obtain `NovaPaySDKFramework.xcframework`
2. Drag it into your Xcode project
3. In your target's General > Frameworks, Libraries, and Embedded Content, set it to **Embed & Sign**
4. Import the framework in your Swift files:
```swift
import NovaPaySDKFramework
```

## 🚀 Getting Started

### Initialization

Initialize the SDK in your `AppDelegate` or `SceneDelegate`:

```swift
import NovaPaySDKFramework

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Initialize SDK
        NPAPIClient.shared.configure(
            with: .staging, // Options: .prod, .staging, .development(url) . By default .staging
            languageType: .uk // Options: uk, en . By default uk
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
    private let sessionIds: [String]
    private let merchantIdentifier: String
    private let payButton = UIButton()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPaymentSheet()
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
    }
    
    // MARK: - Payment Setup
    private func setupPaymentSheet() {
        // Disable the button until payment sheet is ready
        payButton.isEnabled = false
        payButton.setTitle("Loading...", for: .normal)

        Task {
            do {
                // Initialize the payment sheet
                self.paymentSheet = try await PaymentSheet(
                    sessionIds: sessionIds,
                    merchantIdentifier: merchantIdentifier,
                    environment: .staging, // Optional
                    language: .uk // Optional
                )

                // Enable the button when payment sheet is ready
                self.payButton.isEnabled = true
                self.payButton.setTitle("Pay Now", for: .normal)
            } catch {
                self.handleError(error)
            }
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
            paymentSheetStatus: { [weak self] sessionId, orderNumber, result in
                self?.handlePaymentSheetStatus(result)
            },
            on3DsRequired: { [weak self] in
                self?.handleOn3DsRequired()
            }
        )
    }

    // MARK: - Callbacks
    private func handleSessionStatus(_ status: NPSessionStatusType) {
        switch status {
        case .holded:
            showAlert(title: "Payment Successful", message: "Your payment was processed successfully.")
        case .failed:
            showAlert(title: "Payment Failed", message: "There was an issue processing your payment.")
        // Add other cases as needed based on your NPSessionStatusType enum
        default:
            break
        }
    }
    
    private func handlePaymentSheetStatus(_ result: PaymentSheetResult) {
        switch result {
        case .canceled:
            print("Payment was canceled by user")
        case .undefined:
            print("Payment status is undefined")
        // Add other cases as needed
        default:
            break
        }
    }
    
    private func handleOn3DsRequired() {
        paymentSheet?.show3DsScreen()
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
    @State private var showPaymentSheet = false
    
    var body: some View {
        VStack {
            if paymentModel.isLoading {
                ProgressView("Preparing payment...")
            } else {
                // Standard button approach
                Button("Pay with Standard Button") {
                    paymentModel.fetchSessionIdAndInitializePayment()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                // PaymentButton convenience wrapper approach
                if let paymentSheet = paymentModel.paymentSheet {
                    PaymentSheet.PaymentButton(
                        paymentSheet: paymentSheet,
                        paymentSheetStatus: paymentModel.handlePaymentSheetStatus,
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
                            paymentSheetStatus: paymentModel.handlePaymentSheetStatus,
                            on3DsRequired: paymentModel.handleOn3DsRequired
                        )
                }
            }
        }
        .padding()
        .alert(isPresented: $paymentModel.showError) {
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
    @Published var showError = false
    @Published var errorMessage: String?
    
    private var sessionIds: [String]?
    
    func fetchSessionIdAndInitializePayment() {
        isLoading = true
        
        // Call your backend to get a session ID
        getSessionId { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let sessionId):
                self.preparePaymentSheet(sessionIds: [sessionId])
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.showError(message: error.localizedDescription)
                }
            }
        }
    }
    
    private func getSessionId(completion: @escaping (Result<String, Error>) -> Void) {
        // Implement your API call to get session ID from your backend
        // For example purposes, we're returning a mock result
        completion(.success("mock_session_id"))
    }
    
    func preparePaymentSheet(sessionIds: [String]) {
        Task {
            do {
                let sheet = try await PaymentSheet(
                    sessionIds: sessionIds,
                    merchantIdentifier: "Your merchantIdentifier",
                    environment: .staging
                )

                await MainActor.run {
                    self.sessionIds = sessionIds
                    self.paymentSheet = sheet
                    self.isPresentedPaymentSheet = true
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
    
    func handlePaymentSheetStatus(sessionId: String?, orderNumber: String?, result: PaymentSheetResult) {
        switch result {
            case .canceled:
                dismissPaymentSheet()
                print("Canceled!")
            case .undefined:
                dismissPaymentSheet()
                print("Undefined!")
            case .failed(let errorMessage):
                showError(message: errorMessage)
            case .completed:
                print("Completed!")
                dismissPaymentSheet()
        }
    }

    // Called by the SDK when the payment requires 3DS verification
    func handleOn3DsRequired() {
        paymentSheet?.show3DsScreen()
    }

    func handleError(error: Error) {
        showError(message: error.localizedDescription)
        dismissPaymentSheet()
    }
    
    private func dismissPaymentSheet() {
        paymentSheet?.dismiss()
        isPresentedPaymentSheet = false
    }
    
    func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    func startPolling() {
        guard let sessionId = sessionIds?.first else { return }
        
        let sessionService = NPSessionStatusService()
        Task {
            try await sessionService.startPolling(sessionId: sessionId) { result in
                // Handle polling results
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
    case undefined                       // Payment sheet was closed with undefined status
    case canceled                        // User canceled the payment
    case failed(String)                  // Payment failed with a reason
    case completed(NPSessionStatusType?) // Session reported its status
}
```

#### Advanced Usage
Polling for Payment Status
For payments that require additional processing time, you can implement polling:

```swift
func startPolling(sessionId: String) {
    let sessionService = NPSessionStatusService()
    Task {
        try await sessionService.startPolling(sessionId: sessionId) { result in
            switch result {
            case .completed(let status):
                guard let status = status else { return }
                
                // Handle different status types
                switch status {
                case .paid:
                    // Payment successful
                    Task {
                        await sessionService.stopPolling()
                    }
                case .processing, .preprocessing, .holded, .voided:
                    // Handle other statuses
                    break
                @unknown default:
                    break
                }
                
            case .failed(let reason):
                // Payment failed
                // Show error message to user
                print("Polling error: \(reason)")
                
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
Task {
    do {
        let session = try await NPAPIClient.shared.getSession(sessionId: "your_session_id")
        print("Session: \(String(describing: session))")
    } catch {
        print("Error: \(error)")
    }
}
```

Load several sessions at once. `PaymentSheet` uses this call internally for the identifiers it is created with:

```swift
Task {
    do {
        let bulk = try await NPAPIClient.shared.getSessionBulk(
            sessionIds: ["your_session_id_1", "your_session_id_2"]
        )
        print("Sessions: \(String(describing: bulk))")
    } catch {
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
        // The initializer does not block: it starts loading the session in the
        // background, and the sheet shows a skeleton until the data arrives.
        self.walletSheet = WalletSheet(token: token)
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
                            walletSheet: walletSheet,
                            onDismiss: walletModel.onWalletDismiss
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
        walletSheet = WalletSheet(token: token)
    }
    
    func onWalletDismiss() {
        isPresentedWalletSheet = false
        walletSheet = nil
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
        let walletSheet = WalletSheet(token: token)
        // Use wallet sheet — the session loads in the background
    case .failure(let error):
        print("Failed to get auth token: \(error)")
    }
}
```

#### Loading and Errors

`WalletSheet(token:)` returns immediately and starts loading the session in the
background. `present(from:onDismiss:)` can therefore be called right away: the
sheet appears with a skeleton placeholder and fills in once the data arrives.
If the session was already loaded by the time the user taps, no skeleton is shown.

When loading fails, the sheet shows an alert and closes after the user taps OK,
calling `onDismiss`. The failure is **not** reported to the integration:
`WalletSheetResult` is not public in this release, so `WalletSheet` has no result
channel. Error handling that previously lived in the `catch` around
`WalletSheet.init` no longer runs.

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
            payoutSheet = PayoutSheet(sessionId: "your_session_id")
        }
    }

    func handlePayoutStatus(_ result: PayoutSheetResult) {
        switch result {
        case .success(let cardId, let pan):
            print("Payout card saved: \(cardId) \(pan)")
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
        view.addSubview(payoutButton)
        // Add layout constraints here
    }

    private func setupPayoutSheet() {
        payoutSheet = PayoutSheet(sessionId: sessionId)
    }

    @objc private func payoutButtonTapped() {
        guard let sheet = payoutSheet else { return }
        sheet.present(from: self) { result in
            switch result {
            case .success(let cardId, let pan):
                print("Payout card saved: \(cardId) \(pan)")
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

#### Loading and Errors

`PayoutSheet(sessionId:payoutSheetStatusHandler:)` returns immediately and loads
the session in the background, so `present(from:)` can be called right away. The
sheet opens with a skeleton placeholder and fills in once the data arrives.

When loading fails, the sheet closes itself and reports
`PayoutSheetResult.failed(String)` through the status handler. The SDK shows no
alert of its own — presenting the error is yours to do, exactly as it was when
`init` threw.

#### Result Types

```swift
@frozen public enum PayoutSheetResult {
    case undefined
    case canceled
    case failed(String)
    case success(String, String) // saved card id, masked pan
}
```

#### Integration Highlights

- ✅ SwiftUI + UIKit support
- ✅ `.payoutSheet` ViewModifier and `PaymentButton` view
- ✅ Non-blocking initializer with a skeleton while the session loads
- ✅ Every exit reported through a single status handler


## 📱 Example Project

The SDK includes a complete example project in the `Examples/PaymentSheet Example` directory. To run the example:

1. Open `Examples/PaymentSheet Example/PaymentSheet Example.xcodeproj`
2. Select the "PaymentSheet Example" scheme
3. Run the project

The example demonstrates:
- SDK initialization
- Payment sheet integration
- Session management
- Error handling
- UI customization

## ⚙️ Requirements

- iOS 15.0+
- Xcode 16.0+
- Swift 6.0 toolchain (`swift-tools-version: 6.0`)
- Internet permission in Info.plist:
    ```xml
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    ```

## 🌍 Environment Configuration

```swift
public enum NPEnvironmentType: Hashable {
    case prod
    case staging
    case development(String)
}
```

| Case | Host | Description |
|---|---|---|
| `.prod` | `https://e-com.novapay.ua` | Production environment |
| `.staging` | `https://qecom.novapay.ua` | Pre-production testing environment |
| `.development(String)` | your own URL | Development and testing environment |

```swift
NPAPIClient.shared.configure(with: .staging, languageType: .uk)
NPAPIClient.shared.configure(with: .development("https://your-dev-host"))
```

Both parameters are optional, so the language can be changed on its own:

```swift
NPAPIClient.shared.configure(languageType: .uk)
```

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
