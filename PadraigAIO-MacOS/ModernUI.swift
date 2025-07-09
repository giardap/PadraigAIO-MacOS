//
//  ModernUI.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/24/25.
//

import SwiftUI
import SwiftData

// MARK: - Modern Content View
struct ModernContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var wallets: [Wallet]
    @Query private var sniperConfigs: [SniperConfig]
    @Query private var transactions: [TransactionRecord]
    
    @State private var selectedSection: AppSection = .dashboard
    @State private var walletManager: WalletManager?
    @State private var webSocketManager = PumpPortalWebSocketManager()
    @State private var sniperEngine: SniperEngine?
    @State private var pairScannerManager: PairScannerManager?
    @State private var isInitialized = false
    
    @StateObject private var notificationManager = NotificationManager.shared
    
    enum AppSection: String, CaseIterable {
        case dashboard = "Dashboard"
        case pairScanner = "Pair Scanner"
        case wallets = "Wallets"
        case sniper = "Sniper"
        case transactions = "Transactions"
        case analytics = "Analytics"
        
        var icon: String {
            switch self {
            case .dashboard: return "chart.line.uptrend.xyaxis"
            case .pairScanner: return "scope"
            case .wallets: return "wallet.pass"
            case .sniper: return "target"
            case .transactions: return "list.bullet.rectangle"
            case .analytics: return "chart.bar"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            if let pairScannerManager = pairScannerManager {
                ModernSidebar(
                    selectedSection: $selectedSection,
                    walletManager: walletManager,
                    sniperEngine: sniperEngine,
                    webSocketManager: webSocketManager,
                    pairScannerManager: pairScannerManager
                )
            } else {
                // Fallback sidebar without pair scanner
                VStack {
                    Text("Loading...")
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                .frame(minWidth: 280, maxWidth: 320)
                .background(PadraigTheme.sidebarBackground)
            }
        } detail: {
            // Main Content
            Group {
                if isInitialized, 
                   let walletManager = walletManager,
                   let sniperEngine = sniperEngine,
                   let pairScannerManager = pairScannerManager {
                    ModernMainContent(
                        selectedSection: selectedSection,
                        walletManager: walletManager,
                        sniperEngine: sniperEngine,
                        webSocketManager: webSocketManager,
                        pairScannerManager: pairScannerManager,
                        transactions: transactions
                    )
                } else {
                    ModernLoadingView()
                }
            }
        }
        .onAppear {
            initializeManagers()
        }
        .background(PadraigTheme.primaryBackground)
        .overlay(alignment: .topTrailing) {
            ToastContainer(notificationManager: notificationManager)
                .padding()
        }
    }
    
    private func initializeManagers() {
        if walletManager == nil {
            let newWalletManager = WalletManager(modelContext: modelContext)
            walletManager = newWalletManager
        }
        
        if sniperEngine == nil {
            let newSniperEngine = SniperEngine(modelContext: modelContext)
            sniperEngine = newSniperEngine
            
            if let walletManager = walletManager {
                newSniperEngine.setWalletManager(walletManager)
            }
        }
        
        if pairScannerManager == nil {
            let newPairScannerManager = PairScannerManager()
            pairScannerManager = newPairScannerManager
        }
        
        isInitialized = true
    }
}

// MARK: - Modern Sidebar
struct ModernSidebar: View {
    @Binding var selectedSection: ModernContentView.AppSection
    let walletManager: WalletManager?
    let sniperEngine: SniperEngine?
    @ObservedObject var webSocketManager: PumpPortalWebSocketManager
    @ObservedObject var pairScannerManager: PairScannerManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Logo
            HStack(spacing: 12) {
                // Logo
                Image("PadraigLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("PadraigAIO")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(PadraigTheme.primaryText)
                    
                    Text("Trading Suite")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.padraigOrange)
                }
                
                Spacer()
            }
            .padding()
            
            // Scanner Status
            ModernScannerStatus(pairScannerManager: pairScannerManager)
                .padding(.horizontal)
            
            Divider()
                .padding(.vertical)
            
            // Navigation
            VStack(spacing: 4) {
                ForEach(ModernContentView.AppSection.allCases, id: \.self) { section in
                    ModernSidebarButton(
                        section: section,
                        isSelected: selectedSection == section
                    ) {
                        selectedSection = section
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Quick Stats
            if let walletManager = walletManager, let sniperEngine = sniperEngine {
                ModernQuickStats(walletManager: walletManager, sniperEngine: sniperEngine)
                    .padding()
            }
        }
        .frame(minWidth: 280, maxWidth: 320)
        .background(PadraigTheme.sidebarBackground)
    }
}

// MARK: - Modern Sidebar Button
struct ModernSidebarButton: View {
    let section: ModernContentView.AppSection
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .frame(width: 20)
                    .foregroundColor(isSelected ? .white : PadraigTheme.secondaryText)
                
                Text(section.rawValue)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isSelected ? .white : PadraigTheme.secondaryText)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.padraigPrimaryGradient)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.clear)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - Modern Scanner Status
struct ModernScannerStatus: View {
    @ObservedObject var pairScannerManager: PairScannerManager
    
    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
                
                Text("\(pairScannerManager.pairs.count) pairs")
                    .font(.caption2)
                    .foregroundColor(PadraigTheme.secondaryText.opacity(0.7))
            }
            
            Spacer()
            
            // Scanner controls
            Button(action: toggleScanner) {
                Image(systemName: pairScannerManager.isScanning ? "stop.circle.fill" : "play.circle.fill")
                    .foregroundColor(pairScannerManager.isScanning ? .padraigRed : .padraigTeal)
            }
            .buttonStyle(.plain)
            .help(pairScannerManager.isScanning ? "Stop Pair Scanner" : "Start Pair Scanner")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        pairScannerManager.isScanning ? .padraigTeal : .gray
    }
    
    private var statusText: String {
        pairScannerManager.isScanning ? "Scanning Active" : "Scanner Stopped"
    }
    
    private func toggleScanner() {
        if pairScannerManager.isScanning {
            pairScannerManager.stopScanning()
        } else {
            pairScannerManager.startScanning()
        }
    }
}

// MARK: - Modern Quick Stats
struct ModernQuickStats: View {
    @ObservedObject var walletManager: WalletManager
    @ObservedObject var sniperEngine: SniperEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Stats")
                .font(.headline)
                .foregroundColor(PadraigTheme.primaryText)
            
            VStack(spacing: 8) {
                StatRow(title: "Total Balance", value: "\(totalBalance.formatted(.number.precision(.fractionLength(3)))) SOL")
                StatRow(title: "Active Wallets", value: "\(activeWalletCount)")
                StatRow(title: "Today's Snipes", value: "\(sniperEngine.todaySnipeCount)")
                
                if let stats = sniperEngine.stats {
                    StatRow(title: "Success Rate", value: "\(stats.successRate.formatted(.number.precision(.fractionLength(1))))%")
                }
            }
        }
        .padding(16)
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
    }
    
    private var totalBalance: Double {
        walletManager.balances.values.reduce(0, +)
    }
    
    private var activeWalletCount: Int {
        walletManager.wallets.filter { $0.isActive }.count
    }
}

// MARK: - Stat Row
struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(PadraigTheme.primaryText)
        }
    }
}

// MARK: - Modern Main Content
struct ModernMainContent: View {
    let selectedSection: ModernContentView.AppSection
    let walletManager: WalletManager
    let sniperEngine: SniperEngine
    let webSocketManager: PumpPortalWebSocketManager
    let pairScannerManager: PairScannerManager
    let transactions: [TransactionRecord]
    
    var body: some View {
        Group {
            switch selectedSection {
            case .dashboard:
                DashboardView(
                    webSocketManager: webSocketManager,
                    walletManager: walletManager,
                    sniperEngine: sniperEngine
                )
            case .pairScanner:
                PairScannerView(pairManager: pairScannerManager, walletManager: walletManager, sniperEngine: sniperEngine)
            case .wallets:
                ModernWalletView(walletManager: walletManager)
            case .sniper:
                SniperView(sniperEngine: sniperEngine, walletManager: walletManager)
            case .transactions:
                ModernTransactionView(transactions: transactions)
            case .analytics:
                ModernAnalyticsView(walletManager: walletManager, sniperEngine: sniperEngine)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    PadraigTheme.primaryBackground,
                    Color.padraigRed.opacity(0.05),
                    Color.padraigOrange.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Modern Loading View
struct ModernLoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Initializing PadraigAIO...")
                .font(.headline)
                .foregroundColor(PadraigTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PadraigTheme.primaryBackground)
    }
}

// MARK: - Modern Dashboard
struct ModernDashboard: View {
    @ObservedObject var walletManager: WalletManager
    @ObservedObject var sniperEngine: SniperEngine
    @ObservedObject var webSocketManager: PumpPortalWebSocketManager
    @ObservedObject var pairScannerManager: PairScannerManager
    
    @State private var showCreateWalletDialog = false
    @State private var newWalletName = ""
    @State private var isCreatingWallet = false
    @State private var showSniperRequirement = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Dashboard")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(PadraigTheme.primaryText)
                        Text("Welcome to PadraigAIO")
                            .font(.headline)
                            .foregroundColor(PadraigTheme.secondaryText)
                    }
                    Spacer()
                    
                    // Quick Actions
                    HStack(spacing: 12) {
                        // Create Wallet Button
                        Button(action: { showCreateWalletDialog = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Create Wallet")
                                    .fontWeight(.medium)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.padraigRed)
                        .disabled(isCreatingWallet)
                        
                        // Sniper Control Button with dependency check
                        Button(action: toggleSniper) {
                            HStack(spacing: 8) {
                                Image(systemName: sniperEngine.isActive ? "stop.circle.fill" : "play.circle.fill")
                                Text(sniperEngine.isActive ? "Stop Sniper" : "Start Sniper")
                                    .fontWeight(.medium)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(sniperButtonTint)
                        .disabled(!canEnableSniper && !sniperEngine.isActive)
                        .help(sniperButtonHelpText)
                    }
                }
                
                // Stats Cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    DashboardCard(
                        title: "Portfolio Value",
                        value: "\(totalBalance.formatted(.number.precision(.fractionLength(3)))) SOL",
                        subtitle: "≈ $\((totalBalance * 20).formatted(.number.precision(.fractionLength(2))))",
                        icon: "dollarsign.circle.fill",
                        color: .padraigRed
                    )
                    
                    DashboardCard(
                        title: "Active Wallets",
                        value: "\(activeWalletCount)",
                        subtitle: "of \(walletManager.wallets.count) total",
                        icon: "wallet.pass.fill",
                        color: .padraigTeal
                    )
                    
                    if let stats = sniperEngine.stats {
                        DashboardCard(
                            title: "Success Rate",
                            value: "\(stats.successRate.formatted(.number.precision(.fractionLength(1))))%",
                            subtitle: "\(stats.successfulSnipes) of \(stats.totalAttempts)",
                            icon: "target",
                            color: .padraigOrange
                        )
                    }
                }
                
                // Recent Activity
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Activity")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if sniperEngine.recentMatches.isEmpty {
                        ContentUnavailableView(
                            "No Recent Activity",
                            systemImage: "clock",
                            description: Text("Token matches will appear here")
                        )
                        .frame(height: 200)
                    } else {
                        ForEach(sniperEngine.recentMatches.prefix(5)) { match in
                            RecentMatchCard(match: match)
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showCreateWalletDialog) {
            CreateWalletDialog(
                walletName: $newWalletName,
                isCreating: $isCreatingWallet,
                onCreateWallet: createWallet
            )
        }
        .alert("Scanner Required", isPresented: $showSniperRequirement) {
            Button("OK") { }
        } message: {
            Text("The Pair Scanner must be running to enable the Sniper. Please start the Pair Scanner first to detect new tokens.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var totalBalance: Double {
        walletManager.balances.values.reduce(0, +)
    }
    
    private var activeWalletCount: Int {
        walletManager.wallets.filter { $0.isActive }.count
    }
    
    private var canEnableSniper: Bool {
        pairScannerManager.isScanning
    }
    
    private var sniperButtonTint: Color {
        if !canEnableSniper && !sniperEngine.isActive {
            return .gray
        }
        return sniperEngine.isActive ? .padraigRed : .padraigTeal
    }
    
    private var sniperButtonHelpText: String {
        if !canEnableSniper && !sniperEngine.isActive {
            return "Start the Pair Scanner first to enable the Sniper"
        }
        return sniperEngine.isActive ? "Stop automated token sniping" : "Start automated token sniping"
    }
    
    // MARK: - Methods
    
    private func toggleSniper() {
        if sniperEngine.isActive {
            // Always allow stopping
            sniperEngine.toggleSniper(active: false)
        } else {
            // Check if pair scanner is running before enabling
            if pairScannerManager.isScanning {
                sniperEngine.toggleSniper(active: true)
            } else {
                showSniperRequirement = true
            }
        }
    }
    
    private func createWallet() {
        guard !newWalletName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isCreatingWallet = true
        
        Task {
            let success = await walletManager.createWallet(name: newWalletName.trimmingCharacters(in: .whitespacesAndNewlines))
            
            await MainActor.run {
                isCreatingWallet = false
                if success {
                    newWalletName = ""
                    showCreateWalletDialog = false
                }
            }
        }
    }
}

// MARK: - Dashboard Card
struct DashboardCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PadraigTheme.secondaryBackground)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Recent Match Card
struct RecentMatchCard: View {
    let match: TokenMatch
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(match.token.name)
                    .font(.headline)
                    .foregroundColor(PadraigTheme.primaryText)
                Text("$\(match.token.symbol)")
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Score: \(match.score.formatted(.number.precision(.fractionLength(0))))")
                    .font(.caption)
                    .fontWeight(.medium)
                Text(match.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PadraigTheme.secondaryBackground)
        )
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Create Wallet Dialog
struct CreateWalletDialog: View {
    @Binding var walletName: String
    @Binding var isCreating: Bool
    let onCreateWallet: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.padraigRed)
                
                Text("Create New Wallet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Text("Create a new Solana wallet for trading")
                    .font(.subheadline)
                    .foregroundColor(PadraigTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Input Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Wallet Name")
                    .font(.headline)
                    .foregroundColor(PadraigTheme.primaryText)
                
                TextField("Enter wallet name...", text: $walletName)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isCreating)
                
                Text("Choose a memorable name for your new wallet")
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .disabled(isCreating)
                
                Spacer()
                
                Button(action: {
                    onCreateWallet()
                }) {
                    HStack(spacing: 8) {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                        Text(isCreating ? "Creating..." : "Create Wallet")
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.padraigRed)
                .disabled(walletName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(PadraigTheme.primaryBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}