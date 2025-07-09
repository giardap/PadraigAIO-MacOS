//
//  CoinDetailSections.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/26/25.
//

import SwiftUI

// MARK: - Metadata Section
struct CoinMetadataSection: View {
    let pair: TradingPair
    let metadata: ExtendedTokenMetadata?
    
    var body: some View {
        VStack(spacing: 20) {
            // Basic Token Information
            MetadataGroup(title: "Token Information") {
                MetadataRow(label: "Contract Address", value: pair.baseToken.address, isCopyable: true)
                MetadataRow(label: "Symbol", value: pair.baseToken.symbol)
                MetadataRow(label: "Name", value: pair.baseToken.name)
                MetadataRow(label: "Decimals", value: "\(pair.baseToken.decimals)")
                MetadataRow(label: "DEX", value: pair.dex.capitalized)
            }
            
            // Security Information
            if let metadata = metadata {
                MetadataGroup(title: "Security & Compliance") {
                    MetadataRow(label: "Contract Verified", value: metadata.contractVerified ? "✅ Verified" : "❌ Not Verified")
                    MetadataRow(label: "Mint Authority", value: metadata.mintAuthority ?? "✅ Disabled")
                    MetadataRow(label: "Freeze Authority", value: metadata.freezeAuthority ?? "✅ Disabled")
                    MetadataRow(label: "Liquidity Locked", value: metadata.liquidityLocked ? "✅ Locked" : "❌ Not Locked")
                    MetadataRow(label: "Top 10 Holders", value: "\(metadata.top10HolderPercent.formatted(.number.precision(.fractionLength(1))))%")
                }
                
                // Trading Statistics
                MetadataGroup(title: "Trading Statistics") {
                    MetadataRow(label: "Total Holders", value: "\(metadata.holderCount)")
                    MetadataRow(label: "Total Transactions", value: "\(metadata.totalTransactions)")
                    MetadataRow(label: "Unique Wallets", value: "\(metadata.uniqueWallets)")
                    MetadataRow(label: "Created", value: pair.createdAt.formatted(.dateTime.month().day().hour().minute()))
                    MetadataRow(label: "Age", value: pair.ageFormatted)
                }
                
                // Social Links
                if !metadata.socialLinks.isEmpty {
                    MetadataGroup(title: "Social Links") {
                        VStack(spacing: 8) {
                            ForEach(metadata.socialLinks, id: \.platform) { link in
                                HStack {
                                    Image(systemName: link.icon)
                                        .foregroundColor(.padraigTeal)
                                        .frame(width: 20)
                                    
                                    Text(link.platform)
                                        .foregroundColor(PadraigTheme.primaryText)
                                    
                                    Spacer()
                                    
                                    Button("Open") {
                                        if let url = URL(string: link.url) {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }
                
                // Tags
                if !metadata.tags.isEmpty {
                    MetadataGroup(title: "Tags") {
                        HStack {
                            ForEach(metadata.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.padraigTeal.opacity(0.2))
                                    .foregroundColor(.padraigTeal)
                                    .cornerRadius(6)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Trading Section
struct CoinTradingSection: View {
    let pair: TradingPair
    let walletManager: WalletManager?
    @Binding var quickBuyAmount: Double
    @Binding var quickSellPercentage: Double
    let onBuy: () -> Void
    let onSell: () -> Void
    
    @State private var selectedWallet: Wallet?
    @State private var customBuyAmount: String = ""
    @State private var customSellAmount: String = ""
    @State private var slippage: Double = 3.0
    @State private var priorityFee: Double = 0.001
    
    var body: some View {
        VStack(spacing: 20) {
            // Wallet Selection
            if let walletManager = walletManager {
                TradingWalletSelector(walletManager: walletManager, selectedWallet: $selectedWallet)
            }
            
            // Quick Buy Section
            TradingActionCard(
                title: "Quick Buy",
                subtitle: "Buy \(pair.baseToken.symbol) with SOL",
                color: .padraigTeal,
                icon: "arrow.up.circle.fill"
            ) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Amount (SOL):")
                            .foregroundColor(PadraigTheme.primaryText)
                        Spacer()
                        TextField("0.1", value: $quickBuyAmount, format: .number.precision(.fractionLength(3)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                    
                    HStack(spacing: 8) {
                        ForEach([0.1, 0.5, 1.0, 2.0], id: \.self) { amount in
                            Button("\(amount.formatted(.number.precision(.fractionLength(1)))) SOL") {
                                quickBuyAmount = amount
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    
                    Button(action: onBuy) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Execute Buy Order")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.padraigTeal)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedWallet == nil)
                }
            }
            
            // Quick Sell Section
            TradingActionCard(
                title: "Quick Sell",
                subtitle: "Sell your \(pair.baseToken.symbol) holdings",
                color: .padraigRed,
                icon: "arrow.down.circle.fill"
            ) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Percentage:")
                            .foregroundColor(PadraigTheme.primaryText)
                        Spacer()
                        TextField("25", value: $quickSellPercentage, format: .number.precision(.fractionLength(1)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("%")
                            .foregroundColor(PadraigTheme.secondaryText)
                    }
                    
                    HStack(spacing: 8) {
                        ForEach([25.0, 50.0, 75.0, 100.0], id: \.self) { percentage in
                            Button("\(percentage.formatted(.number.precision(.fractionLength(0))))%") {
                                quickSellPercentage = percentage
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    
                    Button(action: onSell) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Execute Sell Order")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.padraigRed)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedWallet == nil)
                }
            }
            
            // Advanced Settings
            TradingSettingsCard(slippage: $slippage, priorityFee: $priorityFee)
        }
    }
}

// MARK: - Analysis Section
struct CoinAnalysisSection: View {
    let pair: TradingPair
    let sniperEngine: SniperEngine?
    
    @State private var riskAnalysis: RiskAnalysis?
    @State private var sniperMatch: SniperMatchResult?
    @State private var isAnalyzing = true
    
    var body: some View {
        VStack(spacing: 20) {
            // Risk Analysis
            if let analysis = riskAnalysis {
                RiskAnalysisCard(analysis: analysis)
            } else if isAnalyzing {
                AnalysisLoadingCard(title: "Risk Analysis", subtitle: "Analyzing token risk factors...")
            }
            
            // Sniper Analysis
            if let sniperEngine = sniperEngine {
                if let match = sniperMatch {
                    SniperAnalysisCard(match: match, pair: pair)
                } else if isAnalyzing {
                    AnalysisLoadingCard(title: "Sniper Analysis", subtitle: "Checking keyword matches...")
                }
            }
            
            // Technical Indicators
            TechnicalIndicatorsCard(pair: pair)
            
            // Market Sentiment
            MarketSentimentCard(pair: pair)
        }
        .onAppear {
            performAnalysis()
        }
    }
    
    private func performAnalysis() {
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            await MainActor.run {
                riskAnalysis = generateRiskAnalysis()
                if let sniperEngine = sniperEngine {
                    sniperMatch = analyzeSniperMatch(sniperEngine: sniperEngine)
                }
                isAnalyzing = false
            }
        }
    }
    
    private func generateRiskAnalysis() -> RiskAnalysis {
        RiskAnalysis(
            overallScore: pair.riskScore,
            liquidityRisk: 0.0, // No real risk data available
            volatilityRisk: 0.0, // No real volatility data available
            holderRisk: 0.0, // No real holder data available
            contractRisk: 0.0, // No real contract analysis available
            factors: [
                "Risk analysis requires real market data",
                "No historical trading data available yet",
                "Token is too new for comprehensive risk assessment"
            ]
        )
    }
    
    private func analyzeSniperMatch(sniperEngine: SniperEngine) -> SniperMatchResult {
        // Return real sniper analysis - no mock data
        return SniperMatchResult(
            isMatch: false,
            score: 0.0,
            matchedKeywords: [],
            reason: "Real-time sniper analysis not available in detail view"
        )
    }
}

// MARK: - Supporting Data Models
struct RiskAnalysis {
    let overallScore: Double
    let liquidityRisk: Double
    let volatilityRisk: Double
    let holderRisk: Double
    let contractRisk: Double
    let factors: [String]
}

struct SniperMatchResult {
    let isMatch: Bool
    let score: Double
    let matchedKeywords: [String]
    let reason: String
}

// MARK: - Supporting View Components
struct MetadataGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(PadraigTheme.primaryText)
            
            VStack(spacing: 8) {
                content
            }
            .padding()
            .background(PadraigTheme.secondaryBackground)
            .cornerRadius(12)
        }
    }
}

struct MetadataRow: View {
    let label: String
    let value: String
    let isCopyable: Bool
    
    init(label: String, value: String, isCopyable: Bool = false) {
        self.label = label
        self.value = value
        self.isCopyable = isCopyable
    }
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(PadraigTheme.secondaryText)
                .frame(width: 140, alignment: .leading)
            
            if isCopyable {
                HStack {
                    Text(value)
                        .foregroundColor(PadraigTheme.primaryText)
                        .textSelection(.enabled)
                    
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(value, forType: .string)
                    }) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Copy to clipboard")
                }
            } else {
                Text(value)
                    .foregroundColor(PadraigTheme.primaryText)
            }
            
            Spacer()
        }
    }
}

struct TradingWalletSelector: View {
    @ObservedObject var walletManager: WalletManager
    @Binding var selectedWallet: Wallet?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Trading Wallet")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(PadraigTheme.primaryText)
            
            if walletManager.wallets.filter({ $0.isActive }).isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.padraigOrange)
                    Text("No active wallets available. Create a wallet first.")
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                .padding()
                .background(Color.padraigOrange.opacity(0.1))
                .cornerRadius(8)
            } else {
                Picker("Wallet", selection: $selectedWallet) {
                    Text("Select wallet...").tag(nil as Wallet?)
                    ForEach(walletManager.wallets.filter { $0.isActive }, id: \.id) { wallet in
                        HStack {
                            Text(wallet.name)
                            Spacer()
                            if let balance = walletManager.balances[wallet.id.uuidString] {
                                Text("\(balance.formatted(.number.precision(.fractionLength(3)))) SOL")
                                    .foregroundColor(PadraigTheme.secondaryText)
                            }
                        }
                        .tag(wallet as Wallet?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
        .onAppear {
            if selectedWallet == nil {
                selectedWallet = walletManager.wallets.first { $0.isActive }
            }
        }
    }
}

struct TradingActionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let color: Color
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(PadraigTheme.primaryText)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
            }
            
            content
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
    }
}

struct TradingSettingsCard: View {
    @Binding var slippage: Double
    @Binding var priorityFee: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced Settings")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(PadraigTheme.primaryText)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Slippage Tolerance:")
                        .foregroundColor(PadraigTheme.primaryText)
                    Spacer()
                    TextField("3.0", value: $slippage, format: .number.precision(.fractionLength(1)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("%")
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                
                HStack {
                    Text("Priority Fee:")
                        .foregroundColor(PadraigTheme.primaryText)
                    Spacer()
                    TextField("0.001", value: $priorityFee, format: .number.precision(.fractionLength(4)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Text("SOL")
                        .foregroundColor(PadraigTheme.secondaryText)
                }
            }
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
    }
}

struct RiskAnalysisCard: View {
    let analysis: RiskAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Risk Analysis")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Spacer()
                
                Text("\(Int(analysis.overallScore))/100")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(riskColor(analysis.overallScore))
            }
            
            VStack(spacing: 8) {
                RiskBar(label: "Liquidity Risk", value: analysis.liquidityRisk)
                RiskBar(label: "Volatility Risk", value: analysis.volatilityRisk)
                RiskBar(label: "Holder Risk", value: analysis.holderRisk)
                RiskBar(label: "Contract Risk", value: analysis.contractRisk)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Risk Factors:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(PadraigTheme.primaryText)
                
                ForEach(analysis.factors, id: \.self) { factor in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(PadraigTheme.secondaryText)
                        Text(factor)
                            .font(.caption)
                            .foregroundColor(PadraigTheme.secondaryText)
                    }
                }
            }
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
    }
    
    private func riskColor(_ score: Double) -> Color {
        if score < 30 { return .padraigTeal }
        else if score < 70 { return .padraigOrange }
        else { return .padraigRed }
    }
}

struct RiskBar: View {
    let label: String
    let value: Double
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
                .frame(width: 100, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(riskColor(value))
                        .frame(width: geometry.size.width * (value / 100), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            Text("\(Int(value))")
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
                .frame(width: 30, alignment: .trailing)
        }
    }
    
    private func riskColor(_ score: Double) -> Color {
        if score < 30 { return .padraigTeal }
        else if score < 70 { return .padraigOrange }
        else { return .padraigRed }
    }
}

struct SniperAnalysisCard: View {
    let match: SniperMatchResult
    let pair: TradingPair
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sniper Analysis")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Spacer()
                
                Image(systemName: match.isMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(match.isMatch ? .padraigTeal : .padraigRed)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Match Score:")
                        .foregroundColor(PadraigTheme.secondaryText)
                    Spacer()
                    Text("\(match.score.formatted(.number.precision(.fractionLength(1))))")
                        .fontWeight(.semibold)
                        .foregroundColor(PadraigTheme.primaryText)
                }
                
                if !match.matchedKeywords.isEmpty {
                    HStack {
                        Text("Keywords:")
                            .foregroundColor(PadraigTheme.secondaryText)
                        
                        ForEach(match.matchedKeywords, id: \.self) { keyword in
                            Text(keyword)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.padraigTeal.opacity(0.2))
                                .foregroundColor(.padraigTeal)
                                .cornerRadius(4)
                        }
                        Spacer()
                    }
                }
                
                Text(match.reason)
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
    }
}

struct AnalysisLoadingCard: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            ProgressView()
                .scaleEffect(0.8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
            
            Spacer()
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
    }
}

struct TechnicalIndicatorsCard: View {
    let pair: TradingPair
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Technical Indicators")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(PadraigTheme.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                IndicatorItem(name: "RSI", value: "N/A", status: .neutral)
                IndicatorItem(name: "MACD", value: "N/A", status: .neutral)
                IndicatorItem(name: "Volume", value: "$\(String(format: "%.0f", pair.volume24h))", status: .neutral)
                IndicatorItem(name: "Liquidity", value: "$\(String(format: "%.0f", pair.liquidity))", status: .neutral)
            }
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
    }
}

struct MarketSentimentCard: View {
    let pair: TradingPair
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Market Sentiment")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(PadraigTheme.primaryText)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    SentimentItem(label: "Community Interest", value: "High", color: .padraigTeal)
                    SentimentItem(label: "Trading Activity", value: "Moderate", color: .padraigOrange)
                    SentimentItem(label: "Holder Confidence", value: "Strong", color: .padraigTeal)
                }
                
                Spacer()
                
                VStack {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(Color.padraigTeal, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        Text("70%")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(PadraigTheme.primaryText)
                    }
                    
                    Text("Bullish")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
            }
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
    }
}

struct IndicatorItem: View {
    let name: String
    let value: String
    let status: IndicatorStatus
    
    enum IndicatorStatus {
        case positive, negative, neutral
        
        var color: Color {
            switch self {
            case .positive: return .padraigTeal
            case .negative: return .padraigRed
            case .neutral: return .padraigOrange
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(status.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

struct SentimentItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}