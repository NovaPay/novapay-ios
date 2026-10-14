import SwiftUI
import NovaPaySDKFramework

struct ExamplePaymentSheetSwiftUIView: View {
    @StateObject var viewModel = PaymentViewModel()
    @State private var phoneNumber: String = UserDefaults.standard.string(forKey: "savedPhoneNumber") ?? "+380"
    @Environment(\.colorScheme) var colorScheme
    @State private var enabledWaybills: [String: Bool] = [:]
    @State private var clientURL: String = ""
    @State private var serviceURL: String = ""

    var body: some View {
        VStack {
            if viewModel.isPresentedPaymentSheet {
                if let paymentSheet = viewModel.paymentSheet {
                    LoadingView()
                        .paymentSheet(
                            isPresented: $viewModel.isPresentedPaymentSheet,
                            paymentSheet: paymentSheet,
                            paymentSheetStatus: viewModel.onDispose,
                            on3DsRequired: viewModel.handleOn3DsRequired
                        )
                } else {
                    LoadingView()
                }
            } else if viewModel.isPresentedWallet {
                if let walletSheet = viewModel.walletSheet {
                    LoadingView()
                        .walletSheet(
                            isPresented: $viewModel.isPresentedWallet,
                            walletSheet: walletSheet,
                            onDismiss: viewModel.onDisposeWallet
                        )
                } else {
                    LoadingView()
                }
            } else if viewModel.isPresentedPayout {
                if let payoutSheet = viewModel.payoutSheet {
                    LoadingView()
                        .payoutSheet(
                            isPresented: $viewModel.isPresentedPayout,
                            payoutSheet: payoutSheet,
                            payoutSheetStatusHandler: viewModel.onDisposePayout
                        )
                } else {
                    LoadingView()
                }
            } else if viewModel.isLoading {
                LoadingView()
            } else {
                contentView
                    .padding()
            }
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
        .onAppear(perform: syncEnvironmentFields)
        .alert(isPresented: $viewModel.showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var contentView: some View {
        VStack {
            environmentSelectors
                .padding(.horizontal, 30)
                .padding(.top, 20)

            phoneNumberField
            actionButtons

            if !viewModel.waybills.isEmpty {
                waybillsList
            }

            Spacer()
        }
    }

    private var environmentSelectors: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Environments")
                    .font(.headline)

                Spacer()

                Button("Reset", action: resetEnvironments)
                    .font(.subheadline)
            }

            EnvironmentRow(title: "Pay-frontend", url: $clientURL, onApply: applyClientURL)
            EnvironmentRow(title: "Internal", url: $serviceURL, onApply: applyServiceURL)
        }
    }

    private func syncEnvironmentFields() {
        clientURL = viewModel.selectedEnvironment.apiBaseURL
        serviceURL = viewModel.selectedAPIServiceEnvironment.baseURL
    }

    private func applyClientURL() {
        viewModel.selectEnvironment(clientEnvironment(for: clientURL))
        clientURL = viewModel.selectedEnvironment.apiBaseURL
    }

    private func applyServiceURL() {
        viewModel.selectAPIServiceEnvironment(serviceEnvironment(for: serviceURL))
        serviceURL = viewModel.selectedAPIServiceEnvironment.baseURL
    }

    private func clientEnvironment(for urlString: String) -> NPEnvironmentType {
        switch urlString {
        case NPEnvironmentType.prod.apiBaseURL:
            return .prod
        case NPEnvironmentType.staging.apiBaseURL:
            return .staging
        default:
            return .development(urlString)
        }
    }

    private func serviceEnvironment(for urlString: String) -> NovaPayAPIEnvironmentType {
        switch urlString {
        case NovaPayAPIEnvironmentType.staging.baseURL:
            return .staging
        default:
            return .development(urlString)
        }
    }

    private func resetEnvironments() {
        viewModel.selectEnvironment(.staging)
        viewModel.selectAPIServiceEnvironment(.staging)
        syncEnvironmentFields()
    }

    private var phoneNumberField: some View {
        VStack {
            phoneTextField
                .padding(.horizontal, 30)
                .padding(.top, 20)

            Divider()
                .padding(.horizontal, 30)
                .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private var phoneTextField: some View {
        if #available(iOS 17.0, *) {
            TextField("Phone Number", text: $phoneNumber)
                .onChange(of: phoneNumber) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "savedPhoneNumber")
                }
        } else {
            TextField("Phone Number", text: $phoneNumber)
                .onChange(of: phoneNumber) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "savedPhoneNumber")
                }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 20) {
            Button {
                viewModel.fetchWaybills(phoneNumber: phoneNumber)
            } label: {
                Text("Get Waybills")
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50, alignment: .center)
            }
            .background(.blue)
            .cornerRadius(8)

            Button {
                viewModel.initializeWallet(phone: phoneNumber)
            } label: {
                Text("Wallet")
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50, alignment: .center)
            }
            .background(.blue)
            .cornerRadius(8)

            Button {
                viewModel.initializePayout(phone: phoneNumber)
            } label: {
                Text("Payout")
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50, alignment: .center)
            }
            .background(.blue)
            .cornerRadius(8)
        }
    }

    private var waybillsList: some View {
        List {
            ForEach(viewModel.waybills, id: \.id) { waybill in
                WaybillRowView(
                    waybill: waybill,
                    isEnabled: Binding(
                        get: { enabledWaybills[waybill.id.uuidString] ?? true },
                        set: { enabledWaybills[waybill.id.uuidString] = $0 }
                    )
                )
                .onTapGesture {
                    let activeWaybills = viewModel.waybills.filter {
                        enabledWaybills[$0.id.uuidString] ?? true
                    }
                    guard !activeWaybills.isEmpty else { return }
                    viewModel.initializePayment(waybills: activeWaybills)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Environment Row

struct EnvironmentRow: View {
    let title: String

    @Binding
    var url: String

    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            HStack(spacing: 8) {
                TextField("URL", text: $url)
                    .font(.subheadline)
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
#endif
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(onApply)

                Button("Apply", action: onApply)
                    .font(.subheadline)
            }
        }
    }
}

// MARK: - Waybill Row View

struct WaybillRowView: View {
    let waybill: WaybillsResponse
    @Binding var isEnabled: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(waybill.delivery_metadata.express_waybill)")
                    .font(.headline)
                Text("Total Amount: \(String(format: "%.2f", waybill.totalAmount()))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ProgressView()
    }
}
