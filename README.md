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
        NovaPay.initialize(
            environment: "development" // Options: "development", "staging", "production"
        )
        
        return true
    }
}
```

## 💳 Features

### Payment Sheet

The SDK provides a ready-to-use payment sheet that handles the complete payment flow. Here's a complete example:

```swift
import NovaPaySDK

class PaymentViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPaymentButton()
    }
    
    private func setupPaymentButton() {
        let button = UIButton(type: .system)
        button.setTitle("Pay Now", for: .normal)
        button.addTarget(self, action: #selector(showPaymentSheet), for: .touchUpInside)
        // Add button to your view hierarchy
    }
    
    @objc private func showPaymentSheet() {
        // First, get session ID from your backend
        getSessionId { [weak self] sessionId in
            guard let self = self else { return }
            
            NovaPay.showPaymentSheet(
                viewController: self,
                sessionId: sessionId,
                sessionStatusCallback: { [weak self] status in
                    switch status {
                    case "SUCCESS":
                        self?.handleSuccess()
                    case "FAILED":
                        self?.handleFailure()
                    default:
                        self?.handleOtherStatus(status)
                    }
                },
                paymentSheetStatusCallback: { status in
                    print("PaymentSheet: \(status)")
                }
            )
        }
    }
    
    private func getSessionId(completion: @escaping (String) -> Void) {
        // Implement your API call to get session ID
        // This should be called from your backend
        let sessionId = "your_session_id"
        completion(sessionId)
    }
    
    private func handleSuccess() {
        // Handle successful payment
        print("Payment successful")
    }
    
    private func handleFailure() {
        // Handle failed payment
        print("Payment failed")
    }
    
    private func handleOtherStatus(_ status: String) {
        // Handle other statuses
        print("Payment status: \(status)")
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