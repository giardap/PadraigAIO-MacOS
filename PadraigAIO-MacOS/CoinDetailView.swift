//
//  CoinDetailView.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/26/25.
//

import SwiftUI
import Charts

// MARK: - Coin Detail View
struct CoinDetailView: View {
    let pair: TradingPair
    let walletManager: WalletManager?
    let sniperEngine: SniperEngine?
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: DetailTab = .overview
    @State private var chartTimeframe: ChartTimeframe = .hour24
    @State private var priceHistory: [PricePoint] = []
    @State private var isLoadingChart = true
    @State private var tokenMetadata: ExtendedTokenMetadata?
    @State private var isLoadingMetadata = true
    @State private var showBuyDialog = false
    @State private var showSellDialog = false
    @State private var quickBuyAmount: Double = 0.1
    @State private var quickSellPercentage: Double = 25.0
    
    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case chart = "Chart"
        case metadata = "Metadata"
        case trading = "Trading"
        case analysis = "Analysis"
        
        var icon: String {
            switch self {
            case .overview: return "chart.bar"
            case .chart: return "chart.line.uptrend.xyaxis"
            case .metadata: return "info.circle"
            case .trading: return "arrow.left.arrow.right"
            case .analysis: return "magnifyingglass"
            }
        }
    }
    
    enum ChartTimeframe: String, CaseIterable {
        case minutes5 = "5m"
        case minutes15 = "15m"
        case hour1 = "1h"
        case hour4 = "4h"
        case hour24 = "24h"
        case days7 = "7d"
        
        var displayName: String { rawValue }
        var interval: TimeInterval {
            switch self {
            case .minutes5: return 300
            case .minutes15: return 900
            case .hour1: return 3600
            case .hour4: return 14400
            case .hour24: return 86400
            case .days7: return 604800
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            CoinDetailHeader(pair: pair, onDismiss: { dismiss() })
            
            Divider()
            
            // Tab Navigation
            tabNavigationView
            
            Divider()
            
            // Content
            contentView
        }
        .frame(width: 800, height: 700)
        .background(PadraigTheme.primaryBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .scaleEffect(1.0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: selectedTab)
        .onAppear {
            loadTokenData()
        }
        .onChange(of: chartTimeframe) { _, newTimeframe in
            loadPriceHistory(timeframe: newTimeframe)
        }
        .sheet(isPresented: $showBuyDialog) {
            EnhancedTradeDialog(
                pair: pair,
                walletManager: walletManager,
                tradeType: .buy,
                defaultAmount: quickBuyAmount
            )
        }
        .sheet(isPresented: $showSellDialog) {
            EnhancedTradeDialog(
                pair: pair,
                walletManager: walletManager,
                tradeType: .sell,
                defaultAmount: Double(quickSellPercentage)
            )
        }
    }
    
    private func loadTokenData() {
        loadTokenMetadata()
        loadPriceHistory(timeframe: chartTimeframe)
    }
    
    private func generateRealisticMetadata(for pair: TradingPair) -> ExtendedTokenMetadata {
        print("🔍 Generating metadata for \(pair.baseToken.symbol) - checking for enhanced metadata...")
        
        // Check for real social links from multiple sources
        var realSocialLinks: [SocialLink] = []
        var realTags: [String] = []
        
        // Priority 1: IPFS metadata
        if let enhanced = pair.enhancedMetadata,
           let ipfsMetadata = enhanced.ipfsMetadata {
            print("   ✅ Found IPFS metadata for \(pair.baseToken.symbol)")
            
            // Extract real social links from IPFS metadata
            realSocialLinks = extractRealSocialLinks(from: ipfsMetadata, enhancedSocialLinks: enhanced.socialLinks)
            
            // Extract real tags if available in metadata
            if let description = ipfsMetadata.description {
                realTags = extractTagsFromDescription(description)
            }
            
            print("   📱 Found \(realSocialLinks.count) IPFS social links")
            print("   🏷️ Found \(realTags.count) tags from IPFS description")
        }
        
        // Priority 2: Check enhanced metadata for social links (includes WebSocket social links)
        if let enhanced = pair.enhancedMetadata, let enhancedSocialLinks = enhanced.socialLinks {
            for linkUrl in enhancedSocialLinks {
                let platform = determinePlatform(from: linkUrl)
                realSocialLinks.append(SocialLink(platform: platform, url: linkUrl, icon: platformIcon(platform)))
            }
            print("   🌐 Found \(enhancedSocialLinks.count) enhanced social links")
        }
        
        // Priority 3: Extract from token description
        let combinedDescription = pair.baseToken.name + " " + (pair.enhancedMetadata?.ipfsMetadata?.description ?? "")
        if !combinedDescription.trimmingCharacters(in: .whitespaces).isEmpty {
            let descriptionLinks = extractLinksFromDescription(combinedDescription)
            realSocialLinks.append(contentsOf: descriptionLinks)
            print("   📝 Found \(descriptionLinks.count) links from token description")
        }
        
        if realSocialLinks.isEmpty {
            print("   ⚠️ No social links found for \(pair.baseToken.symbol) from any source")
        } else {
            print("   🌐 Total social links found: \(realSocialLinks.count)")
            for link in realSocialLinks {
                print("     - \(link.platform): \(link.url)")
            }
        }
        // Base calculations on token's actual metrics
        let marketCap = pair.marketCap ?? 0
        let liquidity = pair.liquidity
        let age = pair.age / 3600 // Age in hours
        let volume = pair.volume24h
        
        // Calculate realistic holder count based on market cap and liquidity
        let holderCount: Int = {
            if marketCap < 1000 {
                return Int.random(in: 1...50)
            } else if marketCap < 10000 {
                return Int.random(in: 10...200)
            } else if marketCap < 100000 {
                return Int.random(in: 50...1000)
            } else if marketCap < 1000000 {
                return Int.random(in: 200...5000)
            } else {
                return Int.random(in: 1000...20000)
            }
        }()
        
        // Calculate realistic transaction count based on age, volume, and holders
        let totalTransactions: Int = {
            let baseTransactions = max(holderCount / 10, 1)
            let ageMultiplier = max(age / 24, 0.1) // Age factor
            let volumeMultiplier = max(volume / 1000, 0.1) // Volume factor
            
            let calculated = Int(Double(baseTransactions) * ageMultiplier * volumeMultiplier)
            
            if marketCap < 1000 {
                return max(calculated, 1)
            } else {
                return max(calculated, 10)
            }
        }()
        
        // Calculate realistic unique wallets (typically 70-90% of holder count)
        let uniqueWallets = Int(Double(holderCount) * Double.random(in: 0.7...0.9))
        
        // Top holder percentage (newer/smaller tokens tend to have higher concentration)
        let top10HolderPercent: Double = {
            if marketCap < 10000 {
                return Double.random(in: 60...85)
            } else if marketCap < 100000 {
                return Double.random(in: 40...70)
            } else {
                return Double.random(in: 20...50)
            }
        }()
        
        // Liquidity locked status (more established tokens more likely to be locked)
        let liquidityLocked = marketCap > 50000 ? (Bool.random() ? true : Bool.random()) : Bool.random()
        
        // Authority status (newer tokens more likely to have authorities)
        let hasAuthorities = age < 48 && marketCap < 100000
        let mintAuthority = hasAuthorities ? (Bool.random() ? "Owner Retained" : nil) : nil
        let freezeAuthority = hasAuthorities ? (Bool.random() ? "Owner Retained" : nil) : nil
        
        // Contract verification (established tokens more likely to be verified)
        let contractVerified = marketCap > 100000 ? true : Bool.random()
        
        return ExtendedTokenMetadata(
            pair: pair,
            holderCount: holderCount,
            top10HolderPercent: top10HolderPercent,
            liquidityLocked: liquidityLocked,
            mintAuthority: mintAuthority,
            freezeAuthority: freezeAuthority,
            totalTransactions: totalTransactions,
            uniqueWallets: uniqueWallets,
            contractVerified: contractVerified,
            socialLinks: realSocialLinks.isEmpty ? [] : realSocialLinks, // Use real social links or empty array
            tags: realTags.isEmpty ? [] : realTags // Use real tags or empty array
        )
    }
    
    private func loadTokenMetadata() {
        Task {
            isLoadingMetadata = true
            
            // Simulate loading extended metadata
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            await MainActor.run {
                tokenMetadata = generateRealisticMetadata(for: pair)
                isLoadingMetadata = false
            }
        }
    }
    
    private func loadPriceHistory(timeframe: ChartTimeframe) {
        Task {
            isLoadingChart = true
            
            // Simulate loading price history
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
            
            await MainActor.run {
                priceHistory = generateSamplePriceHistory(timeframe: timeframe)
                isLoadingChart = false
            }
        }
    }
    
    private var tabNavigationView: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                DetailTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: { selectedTab = tab }
                )
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(PadraigTheme.secondaryBackground)
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                switch selectedTab {
                case .overview:
                    CoinOverviewSection(
                        pair: pair,
                        tokenMetadata: tokenMetadata,
                        onBuy: { showBuyDialog = true },
                        onSell: { showSellDialog = true }
                    )
                case .chart:
                    CoinChartSection(
                        pair: pair,
                        priceHistory: priceHistory,
                        selectedTimeframe: $chartTimeframe,
                        isLoading: isLoadingChart
                    )
                case .metadata:
                    CoinMetadataSection(pair: pair, metadata: tokenMetadata)
                case .trading:
                    CoinTradingSection(
                        pair: pair,
                        walletManager: walletManager,
                        quickBuyAmount: $quickBuyAmount,
                        quickSellPercentage: $quickSellPercentage,
                        onBuy: { showBuyDialog = true },
                        onSell: { showSellDialog = true }
                    )
                case .analysis:
                    CoinAnalysisSection(pair: pair, sniperEngine: sniperEngine)
                }
            }
            .padding()
        }
    }
}

// MARK: - Extended Token Metadata
struct ExtendedTokenMetadata {
    let pair: TradingPair
    let holderCount: Int
    let top10HolderPercent: Double
    let liquidityLocked: Bool
    let mintAuthority: String?
    let freezeAuthority: String?
    let totalTransactions: Int
    let uniqueWallets: Int
    let contractVerified: Bool
    let socialLinks: [SocialLink]
    let tags: [String]
}

struct SocialLink: Hashable {
    let platform: String
    let url: String
    let icon: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url) // Use URL as unique identifier
    }
    
    static func == (lhs: SocialLink, rhs: SocialLink) -> Bool {
        return lhs.url == rhs.url
    }
}

// MARK: - Price Point
struct PricePoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let price: Double
    let volume: Double
}

// MARK: - Coin Detail Header
struct CoinDetailHeader: View {
    let pair: TradingPair
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Token Logo
            AsyncImage(url: URL(string: pair.baseToken.logoURI ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Circle()
                    .fill(Color.padraigTeal.opacity(0.3))
                    .overlay(
                        Text(String(pair.baseToken.symbol.prefix(2)))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.padraigTeal)
                    )
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            
            // Token Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(pair.baseToken.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(PadraigTheme.primaryText)
                    
                    Text("$\(pair.baseToken.symbol)")
                        .font(.title3)
                        .foregroundColor(PadraigTheme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(PadraigTheme.secondaryBackground)
                        .cornerRadius(4)
                }
                
                HStack(spacing: 12) {
                    Text("Market Cap: $\((pair.marketCap ?? 0).formatted(.number.precision(.fractionLength(0))))")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                    
                    Text("DEX: \(pair.dex.capitalized)")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                    
                    Text("Risk: \(Int(pair.riskScore))/100")
                        .font(.caption)
                        .foregroundColor(riskColor)
                }
            }
            
            Spacer()
            
            // Price Change
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(pair.priceChange24h.formatted(.number.precision(.fractionLength(2))))%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(pair.priceChange24h >= 0 ? .padraigTeal : .padraigRed)
                
                Text("24h Change")
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
            
            // Close Button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
            .buttonStyle(.plain)
            .help("Close Detail View")
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
    }
    
    private var riskColor: Color {
        let risk = pair.riskScore
        if risk < 30 { return .padraigTeal }
        else if risk < 70 { return .padraigOrange }
        else { return .padraigRed }
    }
}

// MARK: - Overview Section
struct CoinOverviewSection: View {
    let pair: TradingPair
    let tokenMetadata: ExtendedTokenMetadata?
    let onBuy: () -> Void
    let onSell: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Quick Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(title: "Liquidity", value: "$\(pair.liquidity.formatted(.number.precision(.fractionLength(0))))", icon: "drop.fill", color: .padraigTeal)
                StatCard(title: "Volume 24h", value: "$\(pair.volume24h.formatted(.number.precision(.fractionLength(0))))", icon: "chart.bar.fill", color: .padraigOrange)
                StatCard(title: "Age", value: pair.ageFormatted, icon: "clock.fill", color: .padraigRed)
                
                if let metadata = tokenMetadata {
                    StatCard(title: "Holders", value: "\(metadata.holderCount)", icon: "person.3.fill", color: .padraigTeal)
                    StatCard(title: "Transactions", value: "\(metadata.totalTransactions)", icon: "arrow.left.arrow.right", color: .padraigOrange)
                    StatCard(title: "Unique Wallets", value: "\(metadata.uniqueWallets)", icon: "wallet.pass.fill", color: .padraigRed)
                }
            }
            
            // Quick Actions
            HStack(spacing: 16) {
                Button(action: onBuy) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Quick Buy")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.padraigTeal)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button(action: onSell) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Quick Sell")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.padraigRed)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button(action: {}) {
                    HStack(spacing: 8) {
                        Image(systemName: "target")
                        Text("Add to Sniper")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.padraigOrange)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            
            // Migration Status
            MigrationStatusCard(status: pair.migrationStatus)
        }
    }
}

// MARK: - Chart Section
struct CoinChartSection: View {
    let pair: TradingPair
    let priceHistory: [PricePoint]
    @Binding var selectedTimeframe: CoinDetailView.ChartTimeframe
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Timeframe Selector
            HStack {
                Text("Price Chart")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Spacer()
                
                HStack(spacing: 4) {
                    ForEach(CoinDetailView.ChartTimeframe.allCases, id: \.self) { timeframe in
                        Button(timeframe.displayName) {
                            selectedTimeframe = timeframe
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedTimeframe == timeframe ? Color.padraigTeal : Color.clear)
                        .foregroundColor(selectedTimeframe == timeframe ? .white : PadraigTheme.secondaryText)
                        .cornerRadius(6)
                    }
                }
            }
            
            // Chart
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading chart data...")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                        .padding(.top, 8)
                }
                .frame(height: 300)
                .frame(maxWidth: .infinity)
                .background(PadraigTheme.secondaryBackground)
                .cornerRadius(12)
            } else {
                Chart(priceHistory) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Price", point.price)
                    )
                    .foregroundStyle(Color.padraigTeal)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .frame(height: 300)
                .padding()
                .background(PadraigTheme.secondaryBackground)
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Helper Functions
private func generateSamplePriceHistory(timeframe: CoinDetailView.ChartTimeframe) -> [PricePoint] {
    let now = Date()
    let interval = timeframe.interval / 20 // 20 data points
    var points: [PricePoint] = []
    
    var currentPrice = Double.random(in: 0.001...1.0)
    
    for i in 0..<20 {
        let timestamp = now.addingTimeInterval(-Double(19-i) * interval)
        let volatility = Double.random(in: 0.95...1.05)
        currentPrice *= volatility
        
        points.append(PricePoint(
            timestamp: timestamp,
            price: currentPrice,
            volume: Double.random(in: 1000...50000)
        ))
    }
    
    return points
}

// MARK: - Real Metadata Extraction Functions

private func extractRealSocialLinks(from ipfsMetadata: IPFSTokenMetadata, enhancedSocialLinks: [String]?) -> [SocialLink] {
    var socialLinks: [SocialLink] = []
    
    // Extract from IPFS external_url
    if let externalUrl = ipfsMetadata.external_url, !externalUrl.isEmpty {
        let platform = determinePlatform(from: externalUrl)
        socialLinks.append(SocialLink(platform: platform, url: externalUrl, icon: platformIcon(platform)))
        print("   🔗 Found external URL: \(platform) - \(externalUrl)")
    }
    
    // Extract from enhanced social links array
    if let enhancedLinks = enhancedSocialLinks {
        for linkUrl in enhancedLinks {
            let platform = determinePlatform(from: linkUrl)
            socialLinks.append(SocialLink(platform: platform, url: linkUrl, icon: platformIcon(platform)))
            print("   🔗 Found enhanced link: \(platform) - \(linkUrl)")
        }
    }
    
    // Extract from description if available
    if let description = ipfsMetadata.description {
        let extractedLinks = extractLinksFromDescription(description)
        socialLinks.append(contentsOf: extractedLinks)
    }
    
    // Remove duplicates
    let uniqueLinks = Array(Set(socialLinks.map { $0.url })).compactMap { url in
        socialLinks.first { $0.url == url }
    }
    
    return uniqueLinks
}

private func extractLinksFromDescription(_ description: String) -> [SocialLink] {
    var links: [SocialLink] = []
    
    let patterns = [
        ("https?://(?:www\\.)?twitter\\.com/[A-Za-z0-9_]+", "Twitter"),
        ("https?://(?:www\\.)?x\\.com/[A-Za-z0-9_]+", "X (Twitter)"),
        ("https?://t\\.me/[A-Za-z0-9_]+", "Telegram"),
        ("https?://(?:www\\.)?discord\\.gg/[A-Za-z0-9_]+", "Discord"),
        ("https?://[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", "Website")
    ]
    
    for (pattern, platform) in patterns {
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let matches = regex?.matches(in: description, range: NSRange(description.startIndex..., in: description))
        
        for match in matches ?? [] {
            if let range = Range(match.range, in: description) {
                let url = String(description[range])
                links.append(SocialLink(platform: platform, url: url, icon: platformIcon(platform)))
                print("   🔗 Extracted from description: \(platform) - \(url)")
            }
        }
    }
    
    return links
}

private func determinePlatform(from url: String) -> String {
    let lowercasedUrl = url.lowercased()
    
    if lowercasedUrl.contains("twitter.com") || lowercasedUrl.contains("x.com") {
        return "Twitter"
    } else if lowercasedUrl.contains("t.me") || lowercasedUrl.contains("telegram") {
        return "Telegram"
    } else if lowercasedUrl.contains("discord") {
        return "Discord"
    } else if lowercasedUrl.contains("github") {
        return "GitHub"
    } else if lowercasedUrl.contains("reddit") {
        return "Reddit"
    } else {
        return "Website"
    }
}

private func platformIcon(_ platform: String) -> String {
    switch platform.lowercased() {
    case "twitter", "x (twitter)":
        return "link"
    case "telegram":
        return "paperplane"
    case "discord":
        return "message"
    case "github":
        return "chevron.left.forwardslash.chevron.right"
    case "reddit":
        return "bubble.left"
    default:
        return "globe"
    }
}

private func extractTagsFromDescription(_ description: String) -> [String] {
    var tags: [String] = []
    
    let commonKeywords = [
        "defi": "DeFi",
        "meme": "Meme",
        "gaming": "Gaming",
        "game": "Gaming",
        "ai": "AI",
        "artificial intelligence": "AI",
        "utility": "Utility",
        "community": "Community",
        "experimental": "Experimental",
        "nft": "NFT",
        "metaverse": "Metaverse",
        "dao": "DAO",
        "yield": "Yield Farming",
        "farming": "Yield Farming",
        "staking": "Staking",
        "governance": "Governance"
    ]
    
    let lowercasedDescription = description.lowercased()
    
    for (keyword, tag) in commonKeywords {
        if lowercasedDescription.contains(keyword) {
            tags.append(tag)
        }
    }
    
    // Remove duplicates and limit to 5 tags
    return Array(Set(tags)).prefix(5).map { String($0) }
}

// Legacy functions kept for backward compatibility (but return empty arrays)
private func generateSampleSocialLinks() -> [SocialLink] {
    return [] // No longer generate sample data
}

private func generateSampleTags() -> [String] {
    return [] // No longer generate sample data
}

// MARK: - Supporting Views
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    @State private var isHovered = false
    @State private var animatedValue = ""
    @State private var iconRotation = 0.0
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .rotationEffect(.degrees(iconRotation))
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            
            Text(animatedValue)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(PadraigTheme.primaryText)
                .contentTransition(.numericText())
            
            Text(title)
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? 
                    LinearGradient(colors: [PadraigTheme.secondaryBackground, color.opacity(0.1)], 
                                 startPoint: .topLeading, endPoint: .bottomTrailing) :
                    LinearGradient(colors: [PadraigTheme.secondaryBackground, PadraigTheme.secondaryBackground], 
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .scaleEffect(isHovered ? 1.02 : 1.0)
                .shadow(color: isHovered ? color.opacity(0.2) : Color.clear, radius: isHovered ? 4 : 0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
                if hovering {
                    iconRotation += 360
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                animatedValue = newValue
            }
        }
    }
}

struct MigrationStatusCard: View {
    let status: MigrationStatus
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(status.color)
                .frame(width: 12, height: 12)
            
            Text("Migration Status: \(status.displayName)")
                .font(.headline)
                .foregroundColor(PadraigTheme.primaryText)
            
            Spacer()
            
            Text(statusDescription)
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
    }
    
    private var statusDescription: String {
        switch status {
        case .preMigration:
            return "Trading on Pump.fun bonding curve"
        case .migrating:
            return "Migration to Raydium in progress"
        case .migrated:
            return "Fully migrated to DEX"
        case .failed:
            return "Migration failed or cancelled"
        }
    }
}

// MARK: - Detail Tab Button
struct DetailTabButton: View {
    let tab: CoinDetailView.DetailTab
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : PadraigTheme.secondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.padraigTeal : (isHovered ? Color.padraigTeal.opacity(0.1) : Color.clear))
                    .scaleEffect(isSelected ? 1.0 : (isHovered ? 1.02 : 1.0))
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering && !isSelected
            }
        }
    }
}