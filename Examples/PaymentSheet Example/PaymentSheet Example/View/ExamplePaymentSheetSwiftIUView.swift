import SwiftUI
import NovaPaySDKFramework

struct ExamplePaymentSheetSwiftIUView: View {
    @ObservedObject var model = MyBackendModel()
    @State private var textInput: String = ""
    var body: some View {
        VStack {
            if model.isPresentedPaymentSheet {
                if let paymentSheet = model.paymentSheet {
                    ExampleLoadingView()
                        .paymentSheet(
                            isPresented: $model.isPresentedPaymentSheet,
                            paymentSheet: paymentSheet,
                            statusTypeHandler: model.statusHandler,
                            paymentSheetStatusHandler: model.onDispose
                        )
                } else {
                    ExampleLoadingView()
                }
            } else if model.isLoading {
                ExampleLoadingView()
            } else {
                TextField("Session Id", text: $textInput)
                .padding(.horizontal, 30).padding(.top, 20)
                Divider()
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                Button {
                    model.preparePaymentSheet(sessionId: textInput)
                } label: {
                    Text("Buy")
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50, alignment: .center)
                }
                .background(.blue)
                .cornerRadius(8)
            }
        }
        .padding()
    }
}

@MainActor
class MyBackendModel: ObservableObject {
    @Published var paymentSheet: PaymentSheet?
    @Published var isPresentedPaymentSheet: Bool = false
    @Published var isLoading: Bool = false
    private var sessionId: String?

    func preparePaymentSheet(sessionId: String) {
        if sessionId.count == 0 {
            return
        }
        Task {
            isLoading = true
            self.sessionId = sessionId
            let paymentSheet = await PaymentSheet.init(sessionId: sessionId, statusTypeHandler: statusHandler, paymentSheetStatusHandler: onDispose)
            self.paymentSheet = paymentSheet
            isPresentedPaymentSheet = true
            isLoading = false
        }
    }

    func statusHandler(result: NPSessionStatusType) {
        self.paymentSheet?.dismiss()
        finishSwiftUIIssues()
        switch result {
        case .preprocessing:
            print("Payment preprocessing…")
        case .processing:
            print("Payment processing…")
            self.startPolling()
        case .holded:
            print("Payment holded")
        case .voided:
            print("Payment voided")
        case .paid:
            print("Payment paid")
        case .failed:
            print("Payment failed")
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
            await sessionService.startPolling(sessionId: sessionId) { _ in
                print("---------------------------------")
            }
        }
    }
}

struct ExamplePaymentButtonView: View {
    var body: some View {
        HStack {
            Text("Buy").fontWeight(.bold)
        }
        .frame(minWidth: 200)
        .padding()
        .foregroundColor(.white)
        .background(Color.blue)
        .cornerRadius(6)
        .accessibility(identifier: "Buy button")
    }
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
