import SwiftUI
import NovaPaySDKFramework

// MARK: - Main Payment View
struct ExamplePaymentSheetSwiftUIView: View {
    @StateObject var viewModel = PaymentViewModel()
    @State private var phoneNumber: String = UserDefaults.standard.string(forKey: "savedPhoneNumber") ?? "+380"
    @Environment(\.colorScheme) var colorScheme
    @State private var enabledWaybills: [String: Bool] = [:]
    @State private var clientURL = NPEnvironmentType.dev.apiBaseURL
    @State private var serviceURL = NovaPayAPIEnvironmentType.dev.baseURL
    @State private var customURL = ""
    private var clientURLBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedEnvironment.apiBaseURL },
            set: { viewModel.selectedEnvironment = .custom($0) }
        )
    }

    private var serviceURLBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedAPIServiceEnvironment.baseURL },
            set: { viewModel.selectedAPIServiceEnvironment = .custom($0) }
        )
    }

    
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
                    ExamplePaymentSheetSwiftUIView()
                        .walletSheet(
                            isPresented: $viewModel.isPresentedWallet,
                            walletSheet: walletSheet,
                            onDismiss: viewModel.onDispose
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
                            payoutSheetStatusHandler: viewModel.payoutStatusHandler
                        )
                } else {
                    LoadingView()
                }
            } else if viewModel.isLoading {
                LoadingView()
            } else {
                // Content Layout
                contentView
                    .padding()
            }
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
        .alert(isPresented: $viewModel.showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Content view
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
                
                Button("Reset") {
                    viewModel.selectedEnvironment = .dev
                    viewModel.selectedAPIServiceEnvironment = .dev
                }
                .font(.subheadline)
            }
            
            EnvironmentRow(title: "Pay-frontend", url: clientURLBinding)
            EnvironmentRow(title: "Internal", url: serviceURLBinding)
        }
    }

    private func resetEnvironments() {
        clientURL = NPEnvironmentType.dev.apiBaseURL
        serviceURL = NovaPayAPIEnvironmentType.dev.baseURL

        viewModel.selectedEnvironment = .dev
        viewModel.selectedAPIServiceEnvironment = .dev
    }

    // Phone number input field
    private var phoneNumberField: some View {
        VStack {
            if #available(iOS 17.0, *) {
                TextField("Phone Number", text: $phoneNumber)
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    .onChange(of: phoneNumber) { _, newValue in
                        // Save phone number whenever it changes
                        UserDefaults.standard.set(newValue, forKey: "savedPhoneNumber")
                    }
            } else {
                // Fallback on earlier versions
            }
            
            Divider()
                .padding(.horizontal, 30)
                .padding(.bottom, 10)
        }
    }
    
    // Action buttons
    private var actionButtons: some View {
        VStack(spacing: 20) {
            // Button to fetch waybills
            Button {
                viewModel.fetchWaybills(phoneNumber: phoneNumber)
            } label: {
                Text("Get Waybills")
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50, alignment: .center)
            }
            .background(.blue)
            .cornerRadius(8)
            
            // Button to show wallet
            Button {
                viewModel.initializeWallet(phone: phoneNumber)
            } label: {
                Text("Wallet")
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50, alignment: .center)
            }
            .background(.blue)
            .cornerRadius(8)
            
            // Button to show payout
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

    // Waybills list
    private var waybillsList: some View {
        List {
            ForEach(viewModel.waybills, id: \.id) { waybill in
                WaybillRowView(waybill: waybill,
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
                          
                          viewModel.initializePayment(
                              waybills: activeWaybills,
                              environment: viewModel.selectedEnvironment
                          )
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            TextField("URL", text: $url)
                .font(.subheadline)
#if os(iOS)
                .textInputAutocapitalization(.never)
#endif
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
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
        if #available(iOS 14.0, *) {
            ProgressView()
        } else {
            Text("Loading...")
        }
    }
}
