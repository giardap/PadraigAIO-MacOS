//
//  PairScannerComponents.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/24/25.
//

import SwiftUI

// MARK: - Pair Scanner Header
struct PairScannerHeader: View {
    @ObservedObject var pairManager: PairScannerManager
    @Binding var searchText: String
    @Binding var sortBy: PairScannerView.SortOption
    @Binding var showFilters: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Top row with title and status
            HStack {
                HStack(spacing: 12) {
                    Image("PadraigLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                    
                    Text("Pair Scanner")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(PadraigTheme.primaryText)
                }
                
                Spacer()
                
                // Scanner status
                HStack(spacing: 8) {
                    Circle()
                        .fill(pairManager.isScanning ? Color.padraigTeal : Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Text(pairManager.isScanning ? "Multi-Source Detection Active" : "Detection Stopped")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                    
                    Text("• \(pairManager.pairs.count) pairs")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                    
                    let (metadataCount, imageCount) = pairManager.getIPFSCacheStats()
                    if pairManager.isProcessingIPFS {
                        Text("• IPFS: Processing...")
                            .font(.caption)
                            .foregroundColor(.padraigOrange)
                            .animation(.easeInOut(duration: 1.0).repeatForever(), value: pairManager.isProcessingIPFS)
                    } else if metadataCount > 0 || imageCount > 0 {
                        Text("• IPFS: \(metadataCount)m/\(imageCount)i")
                            .font(.caption)
                            .foregroundColor(.padraigOrange)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(PadraigTheme.secondaryBackground)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            
            // Subtitle and error message
            VStack(alignment: .leading, spacing: 4) {
                Text("Real-time discovery: DexScreener API + Pump.fun WebSocket + IPFS metadata enhancement")
                    .font(.subheadline)
                    .foregroundColor(PadraigTheme.secondaryText)
                
                if let errorMessage = pairManager.apiErrorMessage {
                    Text("⚠️ \(errorMessage)")
                        .font(.caption)
                        .foregroundColor(.padraigRed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.padraigRed.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            // Controls row
            HStack(spacing: 16) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(PadraigTheme.secondaryText)
                    
                    TextField("Search tokens...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(PadraigTheme.primaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(PadraigTheme.secondaryBackground)
                .cornerRadius(8)
                .frame(width: 250)
                
                // Sort picker
                HStack {
                    Text("Sort:")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                    
                    Picker("Sort", selection: $sortBy) {
                        ForEach(PairScannerView.SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
                
                Spacer()
                
                // Filter toggle
                Button(action: { showFilters.toggle() }) {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                        .foregroundColor(showFilters ? .padraigTeal : PadraigTheme.secondaryText)
                }
                .buttonStyle(.bordered)
                .tint(showFilters ? .padraigTeal : Color.clear)
                
                // Refresh button
                Button(action: { pairManager.forceRefresh() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .tint(.padraigTeal)
                
                // Scanner control
                Button(action: toggleScanning) {
                    Label(pairManager.isScanning ? "Stop" : "Start", 
                          systemImage: pairManager.isScanning ? "stop.circle" : "play.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(pairManager.isScanning ? .padraigRed : .padraigTeal)
            }
        }
        .padding()
    }
    
    private func toggleScanning() {
        if pairManager.isScanning {
            pairManager.stopScanning()
        } else {
            pairManager.startScanning()
        }
    }
}

// MARK: - Pair Scanner Filters
struct PairScannerFilters: View {
    @ObservedObject var pairManager: PairScannerManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Filters")
                    .font(.headline)
                    .foregroundColor(PadraigTheme.primaryText)
                Spacer()
            }
            
            // DEX Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("DEXs")
                    .font(.subheadline)
                    .foregroundColor(PadraigTheme.primaryText)
                
                HStack(spacing: 12) {
                    ForEach(["raydium", "orca", "pump.fun"], id: \.self) { dex in
                        DEXFilterChip(
                            dex: dex,
                            isSelected: pairManager.selectedDEXs.contains(dex)
                        ) {
                            toggleDEX(dex)
                        }
                    }
                    Spacer()
                }
            }
            
            // Migration Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Migration Status")
                    .font(.subheadline)
                    .foregroundColor(PadraigTheme.primaryText)
                
                HStack(spacing: 12) {
                    ForEach(MigrationStatus.allCases, id: \.self) { status in
                        MigrationStatusChip(
                            status: status,
                            isSelected: pairManager.selectedMigrationStatus.contains(status)
                        ) {
                            toggleMigrationStatus(status)
                        }
                    }
                    Spacer()
                }
            }
            
            // Liquidity and Age filters
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Min Liquidity: $\(Int(pairManager.minLiquidity))")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                    
                    Slider(value: $pairManager.minLiquidity, in: 100...100000, step: 100)
                        .tint(.padraigTeal)
                }
                .frame(width: 200)
                
                VStack(alignment: .leading) {
                    Text("Max Age: \(pairManager.maxAge)h")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                    
                    Slider(value: Binding(
                        get: { Double(pairManager.maxAge) },
                        set: { pairManager.maxAge = Int($0) }
                    ), in: 1...168, step: 1)
                        .tint(.padraigOrange)
                }
                .frame(width: 200)
                
                Spacer()
            }
        }
        .padding()
    }
    
    private func toggleDEX(_ dex: String) {
        if pairManager.selectedDEXs.contains(dex) {
            pairManager.selectedDEXs.remove(dex)
        } else {
            pairManager.selectedDEXs.insert(dex)
        }
    }
    
    private func toggleMigrationStatus(_ status: MigrationStatus) {
        if pairManager.selectedMigrationStatus.contains(status) {
            pairManager.selectedMigrationStatus.remove(status)
        } else {
            pairManager.selectedMigrationStatus.insert(status)
        }
    }
}

// MARK: - DEX Filter Chip
struct DEXFilterChip: View {
    let dex: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: dexIcon)
                    .font(.caption)
                Text(dex.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.padraigTeal.opacity(0.2) : PadraigTheme.secondaryBackground)
            .foregroundColor(isSelected ? .padraigTeal : PadraigTheme.secondaryText)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.padraigTeal : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var dexIcon: String {
        switch dex {
        case "raydium": return "chart.line.uptrend.xyaxis"
        case "orca": return "waveform"
        case "pump.fun": return "pump"
        default: return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - Migration Status Chip
struct MigrationStatusChip: View {
    let status: MigrationStatus
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)
                Text(status.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? status.color.opacity(0.2) : PadraigTheme.secondaryBackground)
            .foregroundColor(isSelected ? status.color : PadraigTheme.secondaryText)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? status.color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pair Card
struct PairCard: View {
    let pair: TradingPair
    let walletManager: WalletManager?
    let sniperEngine: SniperEngine?
    let pairManager: PairScannerManager?
    @State private var showDetails = false
    @State private var showSnipeDialog = false
    @State private var showTrackDialog = false
    @State private var showCoinDetail = false
    @State private var isExecutingTrade = false
    @State private var isHovered = false
    @State private var scale: CGFloat = 1.0
    @State private var shadowRadius: CGFloat = 4
    
    var body: some View {
        Button(action: { 
            withAnimation(.easeInOut(duration: 0.3)) {
                showDetails.toggle() 
            }
        }) {
            VStack(spacing: 0) {
                // Main card content
                HStack(spacing: 16) {
                    // Token Logo
                    TokenImageView(logoURI: pair.baseToken.logoURI, symbol: pair.baseToken.symbol)
                    
                    // Token info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(pair.baseToken.symbol)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(PadraigTheme.primaryText)
                            
                            Text("/")
                                .foregroundColor(PadraigTheme.secondaryText)
                            
                            Text(pair.quoteToken.symbol)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(PadraigTheme.secondaryText)
                            
                            Spacer()
                            
                            // Age badge
                            Text(pair.ageFormatted)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.3))
                                .foregroundColor(PadraigTheme.secondaryText)
                                .cornerRadius(4)
                        }
                        
                        Text(pair.baseToken.name)
                            .font(.caption)
                            .foregroundColor(PadraigTheme.secondaryText)
                            .lineLimit(1)
                    }
                    
                    // DEX and Migration Status
                    VStack(spacing: 4) {
                        Text(pair.dex.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.padraigTeal.opacity(0.2))
                            .foregroundColor(.padraigTeal)
                            .cornerRadius(4)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(pair.migrationStatus.color)
                                .frame(width: 6, height: 6)
                            Text(pair.migrationStatus.displayName)
                                .font(.caption2)
                                .foregroundColor(pair.migrationStatus.color)
                        }
                    }
                    
                    // Metrics
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack {
                            Text("$\(formatNumber(pair.liquidity))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(PadraigTheme.primaryText)
                            Text("Liq")
                                .font(.caption2)
                                .foregroundColor(PadraigTheme.secondaryText)
                        }
                        
                        HStack {
                            Text("$\(formatNumber(pair.volume24h))")
                                .font(.caption)
                                .foregroundColor(PadraigTheme.secondaryText)
                            Text("Vol")
                                .font(.caption2)
                                .foregroundColor(PadraigTheme.secondaryText)
                        }
                        
                        if let marketCap = pair.marketCap {
                            HStack {
                                Text("$\(formatNumber(marketCap))")
                                    .font(.caption)
                                    .foregroundColor(PadraigTheme.secondaryText)
                                Text("MC")
                                    .font(.caption2)
                                    .foregroundColor(PadraigTheme.secondaryText)
                            }
                        }
                    }
                    
                    // Price change
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(pair.priceChange24h >= 0 ? "+" : "")\(pair.priceChange24h.formatted(.number.precision(.fractionLength(1))))%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(pair.priceChange24h >= 0 ? .padraigTeal : .padraigRed)
                        
                        // Risk score
                        HStack(spacing: 4) {
                            Text("Risk: \(Int(pair.riskScore))")
                                .font(.caption2)
                                .foregroundColor(riskColor)
                            
                            RiskIndicator(score: pair.riskScore)
                        }
                    }
                    
                    // Action buttons
                    VStack(spacing: 4) {
                        AnimatedButton(
                            title: isExecutingTrade ? "Trading..." : "Snipe",
                            color: .padraigRed,
                            isDisabled: isExecutingTrade || walletManager == nil
                        ) {
                            print("🎯 Snipe button tapped for \(pair.baseToken.symbol)")
                            print("   WalletManager available: \(walletManager != nil)")
                            print("   Is executing trade: \(isExecutingTrade)")
                            showSnipeDialog = true
                        }
                        
                        AnimatedButton(
                            title: "Track",
                            color: .padraigOrange,
                            isDisabled: sniperEngine == nil
                        ) {
                            print("📊 Track button tapped for \(pair.baseToken.symbol)")
                            print("   SniperEngine available: \(sniperEngine != nil)")
                            showTrackDialog = true
                        }
                        
                        AnimatedButton(
                            title: "Details",
                            color: .padraigTeal,
                            isDisabled: false
                        ) {
                            print("🔍 Details button tapped for \(pair.baseToken.symbol)")
                            showCoinDetail = true
                        }
                    }
                }
                .padding()
                
                // Expanded details (if shown)
                if showDetails {
                    Divider()
                        .transition(.opacity.combined(with: .scale))
                    PairDetailsView(pair: pair)
                        .padding()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? 
                    LinearGradient(colors: [PadraigTheme.secondaryBackground, PadraigTheme.secondaryBackground.opacity(0.8)], 
                                 startPoint: .topLeading, endPoint: .bottomTrailing) :
                    LinearGradient(colors: [PadraigTheme.secondaryBackground, PadraigTheme.secondaryBackground], 
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        )
        .scaleEffect(scale)
        .shadow(color: Color.black.opacity(isHovered ? 0.4 : 0.3), radius: shadowRadius, x: 0, y: isHovered ? 4 : 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
                scale = hovering ? 1.02 : 1.0
                shadowRadius = hovering ? 8 : 4
            }
        }
        .sheet(isPresented: $showSnipeDialog, onDismiss: {
            print("📱 QuickTradeDialog dismissed for \(pair.baseToken.symbol)")
            pairManager?.dialogClosed()
        }) {
            QuickTradeDialog(
                pair: pair,
                walletManager: walletManager,
                isExecuting: $isExecutingTrade,
                action: QuickTradeDialog.TradeAction.buy
            )
            .onAppear {
                print("📱 QuickTradeDialog appeared for \(pair.baseToken.symbol)")
                pairManager?.dialogOpened()
            }
        }
        .sheet(isPresented: $showTrackDialog, onDismiss: {
            print("📱 AddToSniperDialog dismissed for \(pair.baseToken.symbol)")
            pairManager?.dialogClosed()
        }) {
            AddToSniperDialog(
                pair: pair,
                sniperEngine: sniperEngine
            )
            .onAppear {
                print("📱 AddToSniperDialog appeared for \(pair.baseToken.symbol)")
                pairManager?.dialogOpened()
            }
        }
        .sheet(isPresented: $showCoinDetail, onDismiss: {
            print("🪙 CoinDetailView dismissed for \(pair.baseToken.symbol)")
            pairManager?.dialogClosed()
        }) {
            CoinDetailView(
                pair: pair,
                walletManager: walletManager,
                sniperEngine: sniperEngine
            )
            .onAppear {
                print("🪙 CoinDetailView opened for \(pair.baseToken.symbol)")
                pairManager?.dialogOpened()
            }
        }
    }
    
    private var riskColor: Color {
        switch pair.riskScore {
        case 0..<30: return .padraigTeal
        case 30..<70: return .padraigOrange
        default: return .padraigRed
        }
    }
    
    private func formatNumber(_ value: Double) -> String {
        if value >= 1000000 {
            return String(format: "%.1fM", value / 1000000)
        } else if value >= 1000 {
            return String(format: "%.1fK", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Animated Button
struct AnimatedButton: View {
    let title: String
    let color: Color
    let isDisabled: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                action()
            }
        }) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isDisabled ? .gray : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isDisabled ? Color.gray.opacity(0.3) : color)
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                        .shadow(color: isDisabled ? .clear : color.opacity(0.3), radius: isPressed ? 2 : 4, x: 0, y: isPressed ? 1 : 2)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .scaleEffect(scale)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                scale = (hovering && !isDisabled) ? 1.05 : 1.0
            }
        }
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

// MARK: - Risk Indicator
struct RiskIndicator: View {
    let score: Double
    @State private var animatedHeights: [CGFloat] = [0, 0, 0]
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 3, height: animatedHeights[index])
                    .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.1), value: animatedHeights[index])
            }
        }
        .onAppear {
            withAnimation {
                for index in 0..<3 {
                    let threshold = Double(index + 1) * 33.33
                    animatedHeights[index] = score >= threshold ? 8 : 4
                }
            }
        }
        .onChange(of: score) { _, newScore in
            withAnimation(.easeInOut(duration: 0.3)) {
                for index in 0..<3 {
                    let threshold = Double(index + 1) * 33.33
                    animatedHeights[index] = newScore >= threshold ? 8 : 4
                }
            }
        }
    }
    
    private func barColor(for index: Int) -> Color {
        let threshold = Double(index + 1) * 33.33
        if score >= threshold {
            switch index {
            case 0: return .padraigTeal
            case 1: return .padraigOrange
            default: return .padraigRed
            }
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

// MARK: - Pair Details View
struct PairDetailsView: View {
    let pair: TradingPair
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Pair Details")
                    .font(.headline)
                    .foregroundColor(PadraigTheme.primaryText)
                Spacer()
                
                Button("Copy Address") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(pair.address, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.padraigTeal)
            }
            
            // Details grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                DetailItem(title: "Holders", value: "\(pair.holderCount ?? 0)")
                DetailItem(title: "Top Holder", value: "\(Int(pair.topHolderPercent ?? 0))%")
                DetailItem(title: "Created", value: pair.createdAt.formatted(date: .abbreviated, time: .shortened))
                DetailItem(title: "Pair Address", value: "\(pair.address.prefix(8))...")
                DetailItem(title: "Base Token", value: "\(pair.baseToken.address.prefix(8))...")
                DetailItem(title: "Risk Score", value: "\(Int(pair.riskScore))/100")
            }
        }
        .padding()
        .cornerRadius(8)
    }
}

// MARK: - Detail Item
struct DetailItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(PadraigTheme.secondaryText)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(PadraigTheme.primaryText)
        }
    }
}

// MARK: - Token Image View
struct TokenImageView: View {
    let logoURI: String?
    let symbol: String
    @State private var imageLoadFailed = false
    @State private var isLoading = true
    @State private var isHovered = false
    
    var body: some View {
        AsyncImage(url: logoURL) { phase in
            switch phase {
            case .empty:
                // Loading state
                RoundedRectangle(cornerRadius: 8)
                    .fill(PadraigTheme.secondaryBackground)
                    .frame(width: 40, height: 40)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.7)
                            .progressViewStyle(CircularProgressViewStyle(tint: .padraigTeal))
                    )
            case .success(let image):
                // Successfully loaded image
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.padraigTeal.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .scaleEffect(1.0)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            case .failure(_):
                // Failed to load image - show fallback
                TokenFallbackView(symbol: symbol)
            @unknown default:
                // Unknown state - show fallback
                TokenFallbackView(symbol: symbol)
            }
        }
        .frame(width: 40, height: 40)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .animation(.easeInOut(duration: 0.3), value: imageLoadFailed)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    private var logoURL: URL? {
        guard let logoURI = logoURI, !logoURI.isEmpty else { return nil }
        return URL(string: logoURI)
    }
}

// MARK: - Token Fallback View
struct TokenFallbackView: View {
    let symbol: String
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(LinearGradient(
                colors: [fallbackColor.opacity(0.8), fallbackColor.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 40, height: 40)
            .overlay(
                Text(symbolInitials)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var symbolInitials: String {
        let cleaned = symbol.replacingOccurrences(of: "$", with: "").uppercased()
        if cleaned.count >= 2 {
            return String(cleaned.prefix(2))
        } else if cleaned.count == 1 {
            return cleaned
        } else {
            return "?"
        }
    }
    
    private var fallbackColor: Color {
        // Generate a consistent color based on symbol
        let hash = symbol.hash
        let colors: [Color] = [.padraigTeal, .padraigOrange, .padraigRed, .blue, .purple, .green, .pink]
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - Quick Trade Dialog
struct QuickTradeDialog: View {
    let pair: TradingPair
    let walletManager: WalletManager?
    @Binding var isExecuting: Bool
    let action: TradeAction
    
    @State private var selectedWallet: Wallet?
    @State private var tradeAmount: Double = 0.1
    @State private var slippage: Double = 5.0
    @State private var lastTradeResult: String?
    @Environment(\.dismiss) private var dismiss
    
    enum TradeAction {
        case buy, sell
        
        var title: String {
            switch self {
            case .buy: return "Quick Buy"
            case .sell: return "Quick Sell"
            }
        }
        
        var buttonText: String {
            switch self {
            case .buy: return "Buy Now"
            case .sell: return "Sell Now"
            }
        }
        
        var color: Color {
            switch self {
            case .buy: return .green
            case .sell: return .red
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(action.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(PadraigTheme.secondaryBackground)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Token Info Header
                    VStack(spacing: 8) {
                        HStack {
                            Text("\(pair.baseToken.symbol)/\(pair.quoteToken.symbol)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(PadraigTheme.primaryText)
                            
                            Spacer()
                            
                            Text("Risk: \(Int(pair.riskScore))")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(riskColor.opacity(0.2))
                                .foregroundColor(riskColor)
                                .cornerRadius(8)
                        }
                        
                        HStack {
                            Text("Liquidity: $\(formatNumber(pair.liquidity))")
                            Text("•")
                            Text("Volume: $\(formatNumber(pair.volume24h))")
                            Text("•")
                            Text("Age: \(pair.ageFormatted)")
                        }
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                    }
                    .padding()
                    .background(PadraigTheme.secondaryBackground)
                    .cornerRadius(12)
                
                    // Wallet Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Wallet")
                            .font(.headline)
                            .foregroundColor(PadraigTheme.primaryText)
                        
                        if let walletManager = walletManager {
                            if walletManager.wallets.filter({ $0.isActive }).isEmpty {
                                VStack(spacing: 8) {
                                    Text("No active wallets found")
                                        .foregroundColor(.red)
                                    Text("Please create and activate a wallet first")
                                        .font(.caption)
                                        .foregroundColor(PadraigTheme.secondaryText)
                                }
                            } else {
                                Picker("Wallet", selection: $selectedWallet) {
                                    Text("Select wallet...").tag(nil as Wallet?)
                                    ForEach(walletManager.wallets.filter { $0.isActive }, id: \.id) { wallet in
                                        Text("\(wallet.name) (\(walletManager.balances[wallet.publicKey] ?? 0.0, specifier: "%.3f") SOL)")
                                            .tag(wallet as Wallet?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(PadraigTheme.secondaryBackground)
                                .cornerRadius(8)
                            }
                        } else {
                            Text("Wallet manager not available")
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(PadraigTheme.secondaryBackground)
                    .cornerRadius(12)
                    
                    // Trade Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Trade Settings")
                            .font(.headline)
                            .foregroundColor(PadraigTheme.primaryText)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Amount: \(tradeAmount, specifier: "%.3f") SOL")
                                    .foregroundColor(PadraigTheme.primaryText)
                                Spacer()
                                Text("~$\(tradeAmount * 150, specifier: "%.2f")")
                                    .foregroundColor(PadraigTheme.secondaryText)
                            }
                            
                            Slider(value: $tradeAmount, in: 0.01...10.0, step: 0.01)
                                .tint(action.color)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Slippage: \(slippage, specifier: "%.1f")%")
                                .foregroundColor(PadraigTheme.primaryText)
                            
                            Slider(value: $slippage, in: 0.5...20.0, step: 0.5)
                                .tint(.orange)
                        }
                    }
                    .padding()
                    .background(PadraigTheme.secondaryBackground)
                    .cornerRadius(12)
                    
                    // Last Trade Result
                    if let result = lastTradeResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("Success") ? .green : .red)
                            .padding()
                            .background(PadraigTheme.secondaryBackground)
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            
            // Bottom Action Bar
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button(isExecuting ? "Executing..." : action.buttonText) {
                        executeTradeAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(action.color)
                    .disabled(selectedWallet == nil || isExecuting)
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(PadraigTheme.secondaryBackground)
            }
        }
        .frame(width: 500, height: 600)
        .background(PadraigTheme.primaryBackground)
        .onAppear {
            print("💰 QuickTradeDialog opened for \(pair.baseToken.symbol)")
            if let walletManager = walletManager, !walletManager.wallets.isEmpty {
                selectedWallet = walletManager.wallets.first { $0.isActive }
                print("   Auto-selected wallet: \(selectedWallet?.name ?? "None")")
            }
        }
    }
    
    private var riskColor: Color {
        switch pair.riskScore {
        case 0..<30: return .green
        case 30..<70: return .orange
        default: return .red
        }
    }
    
    private func formatNumber(_ value: Double) -> String {
        if value >= 1000000 {
            return String(format: "%.1fM", value / 1000000)
        } else if value >= 1000 {
            return String(format: "%.1fK", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }
    
    private func executeTradeAction() {
        guard let selectedWallet = selectedWallet,
              let walletManager = walletManager else {
            lastTradeResult = "❌ No wallet selected"
            return
        }
        
        isExecuting = true
        lastTradeResult = nil
        
        Task {
            let result = await walletManager.buyToken(
                mint: pair.baseToken.address,
                amount: tradeAmount,
                slippage: slippage,
                wallet: selectedWallet
            )
            
            await MainActor.run {
                isExecuting = false
                if result.success {
                    lastTradeResult = "✅ Success! Signature: \(result.signature?.prefix(8) ?? "N/A")..."
                    
                    // Auto-dismiss after successful trade
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                } else {
                    lastTradeResult = "❌ Failed: \(result.error ?? "Unknown error")"
                }
            }
        }
    }
}

// MARK: - Add to Sniper Dialog
struct AddToSniperDialog: View {
    let pair: TradingPair
    let sniperEngine: SniperEngine?
    @Environment(\.dismiss) private var dismiss
    
    @State private var configName = ""
    @State private var buyAmount: Double = 0.1
    @State private var slippage: Double = 5.0
    @State private var requireConfirmation = false
    @State private var maxDailySpend: Double = 10.0
    @State private var cooldownPeriod: Int = 300
    @State private var twitterAccounts = "" // New field for Twitter accounts
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add to Sniper")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(PadraigTheme.secondaryBackground)
            
            Divider()
            
            ScrollView {
            VStack(spacing: 20) {
                // Token Info Header
                VStack(spacing: 8) {
                    HStack {
                        Text("Add \(pair.baseToken.symbol) to Sniper")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    
                    HStack {
                        Text("Liquidity: $\(formatNumber(pair.liquidity))")
                        Text("•")
                        Text("Risk: \(Int(pair.riskScore))")
                        Text("•")
                        Text("Age: \(pair.ageFormatted)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(PadraigTheme.secondaryBackground)
                .cornerRadius(12)
                
                // Sniper Configuration
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sniper Configuration")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Configuration Name")
                        TextField("e.g., \(pair.baseToken.symbol) Auto-Snipe", text: $configName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Buy Amount: \(buyAmount, specifier: "%.3f") SOL")
                            Spacer()
                            Text("~$\(buyAmount * 150, specifier: "%.2f")")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $buyAmount, in: 0.01...5.0, step: 0.01)
                            .tint(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Slippage: \(slippage, specifier: "%.1f")%")
                        Slider(value: $slippage, in: 1.0...20.0, step: 0.5)
                            .tint(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Max Daily Spend: \(maxDailySpend, specifier: "%.1f") SOL")
                        Slider(value: $maxDailySpend, in: 1.0...100.0, step: 1.0)
                            .tint(.red)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cooldown: \(cooldownPeriod / 60) minutes")
                        Slider(value: Binding(
                            get: { Double(cooldownPeriod) },
                            set: { cooldownPeriod = Int($0) }
                        ), in: 60...3600, step: 60)
                            .tint(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Twitter Accounts (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("e.g., elonmusk, crypto_whale, @binance", text: $twitterAccounts)
                            .textFieldStyle(.roundedBorder)
                        Text("Comma-separated list of Twitter usernames or URLs to monitor")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Require Manual Confirmation", isOn: $requireConfirmation)
                }
                
                Spacer()
                
                }
                .padding()
            }
            
            // Bottom Action Bar
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("Add to Sniper") {
                        addToSniper()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(configName.isEmpty || sniperEngine == nil)
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(PadraigTheme.secondaryBackground)
            }
        }
        .frame(width: 500, height: 700)
        .background(PadraigTheme.primaryBackground)
        .onAppear {
            print("📊 AddToSniperDialog opened for \(pair.baseToken.symbol)")
            configName = "\(pair.baseToken.symbol) Auto-Snipe"
        }
    }
    
    private func formatNumber(_ value: Double) -> String {
        if value >= 1000000 {
            return String(format: "%.1fM", value / 1000000)
        } else if value >= 1000 {
            return String(format: "%.1fK", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }
    
    private func addToSniper() {
        guard let sniperEngine = sniperEngine else { return }
        
        // Create new sniper configuration targeting this specific token
        let newConfig = SniperConfig(name: configName)
        newConfig.enabled = true
        newConfig.symbolKeywords = [pair.baseToken.symbol, pair.baseToken.name]
        newConfig.descriptionKeywords = []
        newConfig.blacklist = []
        newConfig.creatorAddress = nil
        
        // Parse and set Twitter accounts
        if !twitterAccounts.isEmpty {
            let accounts = twitterAccounts.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            newConfig.twitterAccounts = accounts
        }
        newConfig.minLiquidity = pair.liquidity * 0.8
        newConfig.maxSupply = 1000000000
        newConfig.buyAmount = buyAmount
        newConfig.slippage = slippage
        newConfig.maxDailySpend = maxDailySpend
        newConfig.cooldownPeriod = cooldownPeriod
        newConfig.selectedWallets = []
        newConfig.requireConfirmation = requireConfirmation
        newConfig.tradingPool = pair.dex
        newConfig.staggerDelay = 100
        
        sniperEngine.addSniperConfig(newConfig)
        dismiss()
    }
}