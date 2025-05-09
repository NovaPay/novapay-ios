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
            environment: .dev // Options: dev, staging, production
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
    private let sessionId: String
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
                    sessionId: sessionId,
                    merchantIdentifier: merchantIdentifier,
                    environment: .dev,
                    sessionStatusCallback: { [weak self] status in
                        self?.handleSessionStatus(status)
                    },
                    paymentSheetStatusCallback: { [weak self] status in
                        self?.handlePaymentSheetStatus(status)
                    },
                    sessionErrorCallback: { [weak self] error in
                        self?.handleError(error)
                    },
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
            sessionStatusCallback: { [weak self] status in
                self?.handleSessionStatus(status)
            },
            paymentSheetStatusCallback: { [weak self] status in
                self?.handlePaymentSheetStatus(status)
            },
            sessionErrorCallback: { [weak self] error in
                self?.handleError(error)
            },
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
    
    private func handlePaymentSheetStatus(_ status: PaymentSheetStatus) {
        switch status {
        case .canceled:
            print("Payment was canceled by user")
        case .undefined:
            print("Payment status is undefined")
        // Add other cases as needed
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
                        sessionStatusCallback: paymentModel.handleSessionStatus,
                        paymentSheetStatusCallback: paymentModel.handlePaymentSheetStatus,
                        sessionErrorCallback: paymentModel.sessionErrorCallback
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
                            sessionStatusCallback: paymentModel.handleSessionStatus,
                            paymentSheetStatusCallback: paymentModel.handlePaymentSheetStatus,
                            sessionErrorCallback: paymentModel.handleError
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
    
    func fetchSessionIdAndInitializePayment() {
        isLoading = true
        
        // Call your backend to get a session ID
        getSessionId { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let sessionId):
                self.preparePaymentSheet(sessionId: sessionId)
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
    
    func preparePaymentSheet(sessionId: String) {
        Task {
            do {
                let sheet = try await PaymentSheet(
                    sessionId: sessionId,
                    merchantIdentifier: "Your merchantIdentifier",
                    environment: .dev,
                    sessionStatusCallback: handleSessionStatus,
                    paymentSheetStatusCallback: handlePaymentSheetStatus,
                    sessionErrorCallback: handleError
                )
                
                await MainActor.run {
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
    
    func handleSessionStatus(result: NPSessionStatusType) {
        switch result {
        case .preprocessing:
            print("Payment preprocessing...")
        case .processing:
            print("Payment processing...")
            startPolling()
            dismissPaymentSheet()
        case .holded:
            print("Payment on hold")
            dismissPaymentSheet()
        case .voided:
            print("Payment voided")
            dismissPaymentSheet()
        case .paid:
            print("Payment successful")
            dismissPaymentSheet()
        case .failed:
            print("Payment failed")
            dismissPaymentSheet()
            showError(message: "Payment failed")
        @unknown default:
            print("Unknown status")
            dismissPaymentSheet()
        }
    }
    
    func handlePaymentSheetStatus(result: PaymentSheetStatus) {
        switch result {
        case .canceled:
            print("Payment canceled by user")
            dismissPaymentSheet()
        case .undefined:
            print("Payment sheet closed with undefined status")
            dismissPaymentSheet()
        }
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
        guard let paymentSheet = paymentSheet else { return }
        let sessionId = paymentSheet.sessionId
        
        let sessionService = NPSessionStatusService()
        Task {
            await sessionService.startPolling(sessionId: sessionId) { result in
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
@frozen public enum PaymentSheetStatus {
    case undefined // Payment sheet was closed with undefined status
    case canceled  // User canceled the payment
}
```

#### Advanced Usage
Polling for Payment Status
For payments that require additional processing time, you can implement polling:

```swift
func startPolling(sessionId: String) {
    let sessionService = NPSessionStatusService()
    Task {
        await sessionService.startPolling(sessionId: sessionId) { result in
            switch result {
            case .success(let statusItem):
                guard let status = statusItem.status else { return }
                
                // Handle different status types
                switch status {
                case .paid:
                    // Payment successful
                    Task {
                        await sessionService.stopPolling()
                    }
                case .failed:
                    // Payment failed
                    guard let reasonMessage = statusItem.reason_uk else { return }
                    // Show error message to user
                    Task {
                        await sessionService.stopPolling()
                    }
                case .processing, .preprocessing, .holded, .voided:
                    // Handle other statuses
                    break
                @unknown default:
                    break
                }
                
            case .failure(let error):
                // Handle polling error
                print("Polling error: \(error)")
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
