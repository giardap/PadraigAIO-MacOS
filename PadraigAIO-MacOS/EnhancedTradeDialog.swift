//
//  EnhancedTradeDialog.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/26/25.
//

import SwiftUI

// MARK: - Enhanced Trade Dialog
struct EnhancedTradeDialog: View {
    let pair: TradingPair
    let walletManager: WalletManager?
    let tradeType: TradeType
    let defaultAmount: Double
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWallet: Wallet?
    @State private var amount: String = ""
    @State private var slippage: Double = 3.0
    @State private var priorityFee: Double = 0.001
    @State private var useCustomSlippage = false
    @State private var isExecuting = false
    @State private var estimatedOutput: Double = 0
    @State private var estimatedFees: Double = 0
    @State private var priceImpact: Double = 0
    @State private var orderType: OrderType = .market
    @State private var limitPrice: String = ""
    @State private var stopLossPrice: String = ""
    @State private var takeProfitPrice: String = ""
    
    enum TradeType {
        case buy, sell
        
        var title: String {
            switch self {
            case .buy: return "Buy Token"
            case .sell: return "Sell Token"
            }
        }
        
        var color: Color {
            switch self {
            case .buy: return .padraigTeal
            case .sell: return .padraigRed
            }
        }
        
        var icon: String {
            switch self {
            case .buy: return "arrow.up.circle.fill"
            case .sell: return "arrow.down.circle.fill"
            }
        }
    }
    
    enum OrderType: String, CaseIterable {
        case market = "Market"
        case limit = "Limit"
        case stopLoss = "Stop Loss"
        case takeProfit = "Take Profit"
        
        var description: String {
            switch self {
            case .market: return "Execute immediately at current market price"
            case .limit: return "Execute when price reaches specified level"
            case .stopLoss: return "Sell when price drops to protect losses"
            case .takeProfit: return "Sell when price rises to secure profits"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                // Token Info
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: pair.baseToken.logoURI ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Circle()
                            .fill(tradeType.color.opacity(0.3))
                            .overlay(
                                Text(String(pair.baseToken.symbol.prefix(2)))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(tradeType.color)
                            )
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tradeType.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(PadraigTheme.primaryText)
                        
                        Text("\(pair.baseToken.symbol) • \(pair.dex.capitalized)")
                            .font(.caption)
                            .foregroundColor(PadraigTheme.secondaryText)
                    }
                }
                
                Spacer()
                
                // Close Button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(PadraigTheme.secondaryBackground)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Wallet Selection
                    if let walletManager = walletManager {
                        WalletSelectionSection(
                            walletManager: walletManager,
                            selectedWallet: $selectedWallet
                        )
                    }
                    
                    // Order Type Selection
                    OrderTypeSection(
                        orderType: $orderType,
                        tradeType: tradeType
                    )
                    
                    // Amount Input
                    AmountInputSection(
                        amount: $amount,
                        tradeType: tradeType,
                        pair: pair,
                        selectedWallet: selectedWallet,
                        defaultAmount: defaultAmount
                    )
                    
                    // Advanced Order Options
                    if orderType != .market {
                        AdvancedOrderSection(
                            orderType: orderType,
                            limitPrice: $limitPrice,
                            stopLossPrice: $stopLossPrice,
                            takeProfitPrice: $takeProfitPrice,
                            pair: pair
                        )
                    }
                    
                    // Trading Settings
                    TradingSettingsSection(
                        slippage: $slippage,
                        priorityFee: $priorityFee,
                        useCustomSlippage: $useCustomSlippage
                    )
                    
                    // Trade Summary
                    TradeSummarySection(
                        tradeType: tradeType,
                        pair: pair,
                        amount: amount,
                        estimatedOutput: estimatedOutput,
                        estimatedFees: estimatedFees,
                        priceImpact: priceImpact,
                        slippage: slippage
                    )
                    
                    // Execute Button
                    ExecuteTradeButton(
                        tradeType: tradeType,
                        isExecuting: isExecuting,
                        canExecute: canExecuteTrade,
                        action: executeTrade
                    )
                }
                .padding()
            }
        }
        .frame(width: 500, height: 700)
        .background(PadraigTheme.primaryBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onAppear {
            setupInitialValues()
        }
        .onChange(of: amount) { _, newAmount in
            calculateEstimates()
        }
    }
    
    private var canExecuteTrade: Bool {
        guard selectedWallet != nil,
              !amount.isEmpty,
              Double(amount) != nil,
              !isExecuting else { return false }
        
        if orderType != .market {
            switch orderType {
            case .limit:
                return !limitPrice.isEmpty && Double(limitPrice) != nil
            case .stopLoss:
                return !stopLossPrice.isEmpty && Double(stopLossPrice) != nil
            case .takeProfit:
                return !takeProfitPrice.isEmpty && Double(takeProfitPrice) != nil
            default:
                return true
            }
        }
        
        return true
    }
    
    private func setupInitialValues() {
        amount = defaultAmount.formatted(.number.precision(.fractionLength(tradeType == .buy ? 3 : 1)))
        
        if let walletManager = walletManager {
            selectedWallet = walletManager.wallets.first { $0.isActive }
        }
        
        calculateEstimates()
    }
    
    private func calculateEstimates() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            estimatedOutput = 0
            estimatedFees = 0
            priceImpact = 0
            return
        }
        
        // Simulate trade calculations
        switch tradeType {
        case .buy:
            // Buying token with SOL
            estimatedOutput = amountValue * Double.random(in: 1000...100000) // Estimated tokens
            estimatedFees = amountValue * 0.0025 // 0.25% fee
            priceImpact = min(amountValue / pair.liquidity * 100, 15) // Max 15% impact
        case .sell:
            // Selling percentage of holdings
            let tokenBalance = Double.random(in: 1000...50000) // Simulated balance
            let tokensToSell = tokenBalance * (amountValue / 100)
            estimatedOutput = tokensToSell / Double.random(in: 1000...100000) // Estimated SOL
            estimatedFees = estimatedOutput * 0.0025
            priceImpact = min(tokensToSell / 10000, 12) // Simulated impact
        }
    }
    
    private func executeTrade() {
        guard canExecuteTrade else { return }
        
        isExecuting = true
        
        Task {
            // Simulate trade execution
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            await MainActor.run {
                isExecuting = false
                
                // Show success notification
                NotificationManager.shared.success(
                    "\(tradeType.title) Order Executed",
                    "Successfully \(tradeType == .buy ? "bought" : "sold") \(pair.baseToken.symbol)"
                )
                
                dismiss()
            }
        }
    }
}

// MARK: - Dialog Sections
struct WalletSelectionSection: View {
    @ObservedObject var walletManager: WalletManager
    @Binding var selectedWallet: Wallet?
    
    private var activeWallets: [Wallet] {
        walletManager.wallets.filter { $0.isActive }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Wallet")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(PadraigTheme.primaryText)
            
            walletContent
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var walletContent: some View {
        if activeWallets.isEmpty {
            emptyWalletsView
        } else {
            walletListView
        }
    }
    
    private var emptyWalletsView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.padraigOrange)
            Text("No active wallets available")
                .foregroundColor(PadraigTheme.secondaryText)
        }
        .padding()
        .background(Color.padraigOrange.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var walletListView: some View {
        VStack(spacing: 8) {
            ForEach(activeWallets, id: \.id) { wallet in
                WalletOptionRow(
                    wallet: wallet,
                    balance: walletManager.balances[wallet.id.uuidString] ?? 0,
                    isSelected: selectedWallet?.id == wallet.id,
                    onSelect: { selectedWallet = wallet }
                )
            }
        }
    }
}

struct WalletOptionRow: View {
    let wallet: Wallet
    let balance: Double
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(wallet.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(PadraigTheme.primaryText)
                    
                    Text(wallet.publicKey.prefix(8) + "..." + wallet.publicKey.suffix(8))
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(balance.formatted(.number.precision(.fractionLength(4)))) SOL")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(PadraigTheme.primaryText)
                    
                    Text("≈ $\((balance * 20).formatted(.number.precision(.fractionLength(2))))")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.padraigTeal)
                        .font(.title3)
                }
            }
            .padding()
            .background(isSelected ? Color.padraigTeal.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct OrderTypeSection: View {
    @Binding var orderType: EnhancedTradeDialog.OrderType
    let tradeType: EnhancedTradeDialog.TradeType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Type")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(PadraigTheme.primaryText)
            
            VStack(spacing: 8) {
                ForEach(availableOrderTypes, id: \.self) { type in
                    OrderTypeRow(
                        orderType: type,
                        isSelected: orderType == type,
                        onSelect: { orderType = type }
                    )
                }
            }
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
    }
    
    private var availableOrderTypes: [EnhancedTradeDialog.OrderType] {
        switch tradeType {
        case .buy:
            return [.market, .limit]
        case .sell:
            return [.market, .limit, .stopLoss, .takeProfit]
        }
    }
}

struct OrderTypeRow: View {
    let orderType: EnhancedTradeDialog.OrderType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(orderType.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(PadraigTheme.primaryText)
                    
                    Text(orderType.description)
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.padraigTeal)
                }
            }
            .padding()
            .background(isSelected ? Color.padraigTeal.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct AmountInputSection: View {
    @Binding var amount: String
    let tradeType: EnhancedTradeDialog.TradeType
    let pair: TradingPair
    let selectedWallet: Wallet?
    let defaultAmount: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tradeType == .buy ? "Amount to Spend (SOL)" : "Amount to Sell (%)")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(PadraigTheme.primaryText)
            
            HStack {
                TextField(tradeType == .buy ? "0.1" : "25", text: $amount)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                
                Text(tradeType == .buy ? "SOL" : "%")
                    .font(.title3)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
            
            // Quick Amount Buttons
            HStack(spacing: 8) {
                ForEach(Array(quickAmounts.enumerated()), id: \.offset) { index, quickAmount in
                    Button(quickAmount.label) {
                        amount = quickAmount.value.formatted(.number.precision(.fractionLength(quickAmount.decimals)))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
    }
    
    private var quickAmounts: [(label: String, value: Double, decimals: Int)] {
        switch tradeType {
        case .buy:
            return [
                ("0.1 SOL", 0.1, 1),
                ("0.5 SOL", 0.5, 1),
                ("1 SOL", 1.0, 0),
                ("2 SOL", 2.0, 0)
            ]
        case .sell:
            return [
                ("25%", 25.0, 0),
                ("50%", 50.0, 0),
                ("75%", 75.0, 0),
                ("100%", 100.0, 0)
            ]
        }
    }
}

struct AdvancedOrderSection: View {
    let orderType: EnhancedTradeDialog.OrderType
    @Binding var limitPrice: String
    @Binding var stopLossPrice: String
    @Binding var takeProfitPrice: String
    let pair: TradingPair
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Parameters")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(PadraigTheme.primaryText)
            
            switch orderType {
            case .limit:
                PriceInputRow(
                    label: "Limit Price",
                    placeholder: "0.001",
                    price: $limitPrice,
                    suffix: "SOL"
                )
            case .stopLoss:
                PriceInputRow(
                    label: "Stop Loss Price",
                    placeholder: "0.001",
                    price: $stopLossPrice,
                    suffix: "SOL"
                )
            case .takeProfit:
                PriceInputRow(
                    label: "Take Profit Price",
                    placeholder: "0.001",
                    price: $takeProfitPrice,
                    suffix: "SOL"
                )
            default:
                EmptyView()
            }
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
    }
}

struct PriceInputRow: View {
    let label: String
    let placeholder: String
    @Binding var price: String
    let suffix: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(PadraigTheme.primaryText)
            
            Spacer()
            
            HStack {
                TextField(placeholder, text: $price)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                
                Text(suffix)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
        }
    }
}

struct TradingSettingsSection: View {
    @Binding var slippage: Double
    @Binding var priorityFee: Double
    @Binding var useCustomSlippage: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trading Settings")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(PadraigTheme.primaryText)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Slippage Tolerance")
                        .foregroundColor(PadraigTheme.primaryText)
                    
                    Spacer()
                    
                    if useCustomSlippage {
                        HStack {
                            TextField("3.0", value: $slippage, format: .number.precision(.fractionLength(1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("%")
                                .foregroundColor(PadraigTheme.secondaryText)
                        }
                    } else {
                        HStack(spacing: 4) {
                            ForEach([1.0, 3.0, 5.0], id: \.self) { preset in
                                Button("\(preset.formatted(.number.precision(.fractionLength(0))))%") {
                                    slippage = preset
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .background(slippage == preset ? Color.padraigTeal : Color.clear)
                            }
                            
                            Button("Custom") {
                                useCustomSlippage = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                
                HStack {
                    Text("Priority Fee")
                        .foregroundColor(PadraigTheme.primaryText)
                    
                    Spacer()
                    
                    HStack {
                        TextField("0.001", value: $priorityFee, format: .number.precision(.fractionLength(4)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("SOL")
                            .foregroundColor(PadraigTheme.secondaryText)
                    }
                }
            }
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
    }
}

struct TradeSummarySection: View {
    let tradeType: EnhancedTradeDialog.TradeType
    let pair: TradingPair
    let amount: String
    let estimatedOutput: Double
    let estimatedFees: Double
    let priceImpact: Double
    let slippage: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trade Summary")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(PadraigTheme.primaryText)
            
            VStack(spacing: 8) {
                SummaryRow(
                    label: tradeType == .buy ? "You Pay" : "You Sell",
                    value: "\(amount) \(tradeType == .buy ? "SOL" : "% of holdings")"
                )
                
                SummaryRow(
                    label: tradeType == .buy ? "You Receive" : "You Get",
                    value: tradeType == .buy ? 
                        "\(estimatedOutput.formatted(.number.precision(.fractionLength(0)))) \(pair.baseToken.symbol)" :
                        "\(estimatedOutput.formatted(.number.precision(.fractionLength(4)))) SOL"
                )
                
                SummaryRow(
                    label: "Estimated Fees",
                    value: "\(estimatedFees.formatted(.number.precision(.fractionLength(4)))) SOL"
                )
                
                SummaryRow(
                    label: "Price Impact",
                    value: "\(priceImpact.formatted(.number.precision(.fractionLength(2))))%",
                    valueColor: priceImpact > 5 ? .padraigRed : priceImpact > 2 ? .padraigOrange : .padraigTeal
                )
                
                SummaryRow(
                    label: "Max Slippage",
                    value: "\(slippage.formatted(.number.precision(.fractionLength(1))))%"
                )
            }
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    let valueColor: Color?
    
    init(label: String, value: String, valueColor: Color? = nil) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(PadraigTheme.secondaryText)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(valueColor ?? PadraigTheme.primaryText)
        }
    }
}

struct ExecuteTradeButton: View {
    let tradeType: EnhancedTradeDialog.TradeType
    let isExecuting: Bool
    let canExecute: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: tradeType.icon)
                        .font(.title3)
                }
                
                Text(isExecuting ? "Executing..." : "Execute \(tradeType.title)")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canExecute && !isExecuting ? tradeType.color : Color.gray)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(!canExecute || isExecuting)
    }
}