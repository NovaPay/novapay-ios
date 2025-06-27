import SwiftUI
import NovaPaySDKFramework

// MARK: - Main Payment View
struct ExamplePaymentSheetSwiftUIView: View {
    @StateObject var viewModel = PaymentViewModel()
    @State private var phoneNumber: String = UserDefaults.standard.string(forKey: "savedPhoneNumber") ?? "+380"
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedEnvironment: NPEnvironmentType = .dev

    var body: some View {
        VStack {
            if viewModel.isPresentedPaymentSheet {
                if let paymentSheet = viewModel.paymentSheet {
                    LoadingView()
                        .paymentSheet(
                            isPresented: $viewModel.isPresentedPaymentSheet,
                            paymentSheet: paymentSheet,
                            paymentSheetStatus: viewModel.onDispose
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
                            walletSheetStatusHandler: viewModel.walletStatusHandler
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
            // Environment Selection
            environmentSelector
                .padding(.horizontal, 30)
                .padding(.top, 20)
            
            // Phone number input field
            phoneNumberField
            
            // Action Buttons
            actionButtons
            
            // Waybills List
            if !viewModel.waybills.isEmpty {
                waybillsList
            }
            
            Spacer()
        }
    }
    
    // Environment selection view
    private var environmentSelector: some View {
        VStack(alignment: .leading) {
            Text("Environment:")
                .font(.headline)
                .padding(.bottom, 5)
            
            if #available(iOS 17.0, *) {
                RadioButtonGroup(
                    selectedId: $selectedEnvironment,
                    options: [
                        RadioOption(id: .dev, label: "Development"),
                        RadioOption(id: .staging, label: "Staging")
                    ]
                )
                .onChange(of: selectedEnvironment) { _, newValue in
                    // Configure the NPAPIClient with the selected environment
                    NPAPIClient.shared.configure(with: newValue)
                }
                .onAppear {
                    // Trigger initial configuration
                    NPAPIClient.shared.configure(with: selectedEnvironment)
                }
            } else {
                // Fallback on earlier versions
            }
        }
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
                WaybillRowView(waybill: waybill)
                    .onTapGesture {
                        viewModel.initializePayment(
                            waybill: waybill,
                            environment: selectedEnvironment
                        )
                    }
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Waybill Row View
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

// MARK: - Radio Button Components
struct RadioOption<T: Hashable>: Identifiable {
    let id: T
    let label: String
}

struct RadioButtonGroup<T: Hashable>: View {
    @Binding var selectedId: T
    let options: [RadioOption<T>]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(options, id: \.id) { option in
                RadioButton(
                    label: option.label,
                    isSelected: selectedId == option.id,
                    action: { selectedId = option.id }
                )
            }
        }
    }
}

struct RadioButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                    }
                }
                
                Text(label)
                    .foregroundColor(.primary)
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
