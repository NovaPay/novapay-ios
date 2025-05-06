import SwiftUI
import NovaPaySDKFramework

struct ExamplePaymentSheetSwiftIUView: View {
    @ObservedObject var model = MyBackendModel()
    @State private var phoneNumber: String = UserDefaults.standard.string(forKey: "savedPhoneNumber") ?? "+380"
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            if model.isPresentedPaymentSheet {
                if let paymentSheet = model.paymentSheet {
                    ExampleLoadingView()
                        .paymentSheet(
                            isPresented: $model.isPresentedPaymentSheet,
                            paymentSheet: paymentSheet,
                            sessionStatusCallback: model.statusHandler,
                            paymentSheetStatusCallback: model.onDispose
                        )
                } else {
                    ExampleLoadingView()
                }
            } else if model.isLoading {
                ExampleLoadingView()
            } else {
                // Phone number input field
                TextField("Phone Number", text: $phoneNumber)
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    .onChange(of: phoneNumber) { oldValue, newValue in
                        // Save phone number whenever it changes
                        UserDefaults.standard.set(newValue, forKey: "savedPhoneNumber")
                    }
                Divider()
                    .padding(.horizontal, 30)
                    .padding(.bottom, 10)
                
                // Button to fetch waybills
                Button {
                    model.fetchWaybills(phoneNumber: phoneNumber)
                } label: {
                    Text("Get Waybills")
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50, alignment: .center)
                }
                .background(.blue)
                .cornerRadius(8)
                .padding(.bottom, 20)

                List {
                    ForEach(model.waybills, id: \.id) { waybill in
                        WaybillRowView(waybill: waybill)
                            .onTapGesture {
                                model.initializePayment(waybill: waybill)
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.black : Color.white)
        .alert(isPresented: $model.showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(model.errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

@MainActor
class MyBackendModel: ObservableObject {
    @Published var paymentSheet: PaymentSheet?
    @Published var isPresentedPaymentSheet: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showErrorAlert: Bool = false
    @Published var waybills: [WaybillsResponse] = []
    private var sessionId: String?
    
    func fetchWaybills(phoneNumber: String) {
        isLoading = true

        guard let encodedPhone = phoneNumber.addingPercentEncoding(withAllowedCharacters: .allowedCharacters) else {
            isLoading = false
            showError("Invalid phone number format")
            return
        }

        guard let url = URL(string: "https://a2-sdk-internal-api.novapay.ua/v1/express-waybills?phone=\(encodedPhone)") else {
            isLoading = false
            showError("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-type")
        request.addValue("lolkekcheburek", forHTTPHeaderField: "x-token")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.showError("Error fetching waybills: \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
                    self?.showError("No data received")
                    return
                }

                do {
                    let string = String(data: data, encoding: .utf8)!
                    print(string)
                    let waybills = try JSONDecoder().decode([WaybillsResponse].self, from: data)
                    self?.waybills = waybills
                } catch {
                    self?.showError("Error decoding waybills: \(error.localizedDescription)")
                }
            }
        }
        
        task.resume()
    }

    private func showError(_ message: String) {
        self.errorMessage = message
        self.showErrorAlert = true
    }

    func initializePayment(waybill: WaybillsResponse) {
        isLoading = true

        // Create the payment initialization request
        let paymentRequest = PaymentInitRequest.convert(from: waybill)
        
        guard let url = URL(string: "https://a2-sdk-internal-api.novapay.ua/v1/init") else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-type")
        request.addValue("lolkekcheburek", forHTTPHeaderField: "x-token")

        do {
            let jsonData = try JSONEncoder().encode(paymentRequest)
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.showError("Error initializing payment: \(error)")
                        self?.isLoading = false
                        return
                    }
                    
                    guard let data = data else {
                        self?.showError("No data received from init endpoint")
                        self?.isLoading = false
                        return
                    }
                    let string = String(data: data, encoding: .utf8)!
                    print(string)
                    do {
                        let response = try JSONDecoder().decode(PaymentInitResponse.self, from: data)
                        self?.preparePaymentSheet(sessionId: response.session_id)
                    } catch {
                        self?.showError("Error decoding payment init response: \(error)")
                        self?.isLoading = false
                    }
                }
            }

            task.resume()
        } catch {
            self.showError("Error decoding payment request: \(error)")
            isLoading = false
        }
    }

    func preparePaymentSheet(sessionId: String) {
        if sessionId.count == 0 {
            return
        }
        Task {
            self.sessionId = sessionId
            do {
                let paymentSheet = try await PaymentSheet.init(
                    sessionId: sessionId,
                    merchantIdentifier: "merchant.ua.novapay.novapaymobile",
                    sessionStatusCallback: statusHandler,
                    paymentSheetStatusCallback: onDispose
                )
                self.paymentSheet = paymentSheet
                isPresentedPaymentSheet = true
                isLoading = false
            } catch {
                isLoading = false
                self.showError(error.localizedDescription)
            }
        }
    }

    func statusHandler(result: NPSessionStatusType) {
        switch result {
        case .preprocessing:
            print("Payment preprocessing…")
        case .processing:
            print("Payment processing…")
            self.startPolling()
            self.paymentSheet?.dismiss()
            finishSwiftUIIssues()
        case .holded:
            print("Payment holded")
            self.paymentSheet?.dismiss()
            finishSwiftUIIssues()
        case .voided:
            print("Payment voided")
            self.paymentSheet?.dismiss()
            finishSwiftUIIssues()
        case .paid:
            print("Payment paid")
            self.paymentSheet?.dismiss()
            finishSwiftUIIssues()
        case .failed:
            print("Payment failed")
            self.paymentSheet?.dismiss()
            finishSwiftUIIssues()
            self.showError("Payment failed")
        @unknown default:
            print("Unknown")
        }
    }

    func onDispose(result: PaymentSheetStatus) {
        switch result {
            case .canceled:
                self.paymentSheet?.dismiss()
                finishSwiftUIIssues()
                print("Canceled!")
            case .undefined:
                self.paymentSheet?.dismiss()
                finishSwiftUIIssues()
        }
    }

    private func finishSwiftUIIssues() {
        isPresentedPaymentSheet = false
    }

    func startPolling() {
        guard let sessionId = sessionId else { return }
        let sessionService = NPSessionStatusService()
        Task {
            await sessionService.startPolling(sessionId: sessionId) { result in
                switch result {
                case .success(let statusItem):
                    guard let status = statusItem.status else { return }
                    switch status {
                    case .preprocessing:
                        print("Payment preprocessing…")
                    case .processing:
                        print("Payment processing…")
                    case .holded:
                        print("Payment holded")
                    case .voided:
                        print("Payment voided")
                    case .paid:
                        print("Payment paid")
                    case .failed:
                        print("Payment failed")
                        guard let reason_uk = statusItem.reason_uk else { return }
                        Task {
                            await sessionService.stopPolling()
                        }
                        let message = "Payment failed: \(reason_uk)"
                        self.showError(message)
                    @unknown default:
                        print("Unknown")
                    }
                case .failure(let error):
                    print("Error: \(error)")
                }
            }
        }
    }
}

struct WaybillRowView: View {
    let waybill: WaybillsResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(waybill.delivery_metadata.express_waybill)")
                .font(.headline)
            Text("Total Amount: \(String(format: "%.2f", waybill.totalAmount()))")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

struct WaybillsResponse: Decodable {
    let id = UUID()
    let client_first_name: String
    let client_last_name: String
    let client_patronymic: String
    let client_phone: String
    let client_email: String
    let metadata: PaymentMetadata
    let delivery_metadata: DeliveryMetadata
    let recipients: [Recipient]

    func totalAmount() -> Double {
        return recipients.reduce(0) { result, recipient in
            let amount = Double(recipient.amount ?? "0") ?? 0
            return result + amount
        }
    }
}

// Models for payment initialization
struct PaymentInitRequest: Encodable {
    let client_first_name: String
    let client_last_name: String
    let client_patronymic: String
    let client_phone: String
    let client_email: String
    let metadata: PaymentMetadata
    let delivery_metadata: DeliveryMetadata
    let recipients: [Recipient]

    static func convert(from: WaybillsResponse) -> PaymentInitRequest {
        let request = PaymentInitRequest(client_first_name: from.client_first_name, client_last_name: from.client_last_name, client_patronymic: from.client_patronymic, client_phone: from.client_phone, client_email: from.client_email, metadata: from.metadata, delivery_metadata: from.delivery_metadata, recipients: from.recipients)
        return request
    }
}

struct PaymentMetadata: Encodable, Decodable {
    let payer_type: String
    let source: String
    let client_verified: Bool
    let client_npuid: String
    let ref_settlement_recipient: String
    let ref_settlement_sender: String
}

struct DeliveryMetadata: Encodable, Decodable {
    let ref_id: String
    let express_waybill: String
}

struct Recipient: Encodable, Decodable {
    let type: String
    let identifier: String?
    let amount: String? // Using Any to handle both String and Double
    let payment_type: String
    let first_name: String?
    let last_name: String?
    let patronymic: String?
    let phone: String?
    let tax_payer: String?
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        if let identifier = identifier {
            try container.encode(identifier, forKey: .identifier)
        }
        
        // Handle amount which can be String or Double
        if let stringAmount = amount {
            try container.encode(stringAmount, forKey: .amount)
        }
        
        try container.encode(payment_type, forKey: .payment_type)
        
        if let first_name = first_name {
            try container.encode(first_name, forKey: .first_name)
        }
        
        if let last_name = last_name {
            try container.encode(last_name, forKey: .last_name)
        }
        
        if let patronymic = patronymic {
            try container.encode(patronymic, forKey: .patronymic)
        }
        
        if let phone = phone {
            try container.encode(phone, forKey: .phone)
        }
        
        if let tax_payer = tax_payer {
            try container.encode(tax_payer, forKey: .tax_payer)
        }
    }

    enum CodingKeys: String, CodingKey {
        case type, identifier, amount, payment_type, first_name, last_name, patronymic, phone, tax_payer
    }
}

struct PaymentInitResponse: Decodable {
    let session_id: String
}

struct ExampleLoadingView: View {
    var body: some View {
        if #available(iOS 14.0, *) {
            ProgressView()
        } else {
            Text("Preparing payment…")
        }
    }
}

extension CharacterSet {
    static let allowedCharacters = urlQueryAllowed.subtracting(.init(charactersIn: "+"))
}

extension UIViewController {
    func showErrorAlert(title: String = "Error", message: String, buttonTitle: String = "OK", completion: (() -> Void)? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: buttonTitle, style: .default) { _ in
            completion?()
        }
        alertController.addAction(okAction)
        present(alertController, animated: true)
    }
}
