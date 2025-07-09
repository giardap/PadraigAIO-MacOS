//
//  DetailedViews.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/24/25.
//

import SwiftUI
import SwiftData

// MARK: - Enhanced Dashboard View
struct DashboardView: View {
    @ObservedObject var webSocketManager: PumpPortalWebSocketManager
    @ObservedObject var walletManager: WalletManager
    @ObservedObject var sniperEngine: SniperEngine
    @StateObject private var notificationManager = NotificationManager.shared
    
    @State private var selectedToken: TokenCreation?
    @State private var showTokenDetails = false
    @State private var showSniperSettings = false
    @State private var showCreateWallet = false
    @State private var animateMetrics = false
    @State private var newWalletName = ""
    @State private var isCreatingWallet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Dashboard Header with Actions
                DashboardHeader(
                    walletManager: walletManager,
                    sniperEngine: sniperEngine,
                    webSocketManager: webSocketManager,
                    showCreateWallet: $showCreateWallet,
                    showSniperSettings: $showSniperSettings
                )
                
                // Main Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    // Portfolio Overview
                    EnhancedDashboardCard(
                        title: "Portfolio Value",
                        value: "\(totalBalance.formatted(.number.precision(.fractionLength(3)))) SOL",
                        subtitle: "≈ $\((totalBalance * 20).formatted(.number.precision(.fractionLength(2))))",
                        icon: "dollarsign.circle.fill",
                        color: .padraigRed,
                        animate: $animateMetrics
                    )
                    
                    // Active Wallets
                    EnhancedDashboardCard(
                        title: "Active Wallets",
                        value: "\(activeWalletCount)",
                        subtitle: "of \(walletManager.wallets.count) total",
                        icon: "wallet.pass.fill",
                        color: .padraigTeal,
                        animate: $animateMetrics
                    )
                    
                    // Sniper Performance
                    if let stats = sniperEngine.stats {
                        EnhancedDashboardCard(
                            title: "Success Rate",
                            value: "\(stats.successRate.formatted(.number.precision(.fractionLength(1))))%",
                            subtitle: "\(stats.successfulSnipes) of \(stats.totalAttempts)",
                            icon: "target",
                            color: .padraigOrange,
                            animate: $animateMetrics
                        )
                    }
                    
                    // Today's Activity
                    EnhancedDashboardCard(
                        title: "Today's Snipes",
                        value: "\(sniperEngine.todaySnipeCount)",
                        subtitle: "matches found",
                        icon: "clock.fill",
                        color: .blue,
                        animate: $animateMetrics
                    )
                }
                
                // Enhanced Control Center
                HStack(spacing: 20) {
                    // Sniper Control Panel
                    SniperControlPanel(
                        sniperEngine: sniperEngine,
                        webSocketManager: webSocketManager,
                        showSniperSettings: $showSniperSettings,
                        animateMetrics: $animateMetrics
                    )
                    
                    // Quick Actions Panel
                    QuickActionsDashboard(
                        walletManager: walletManager,
                        webSocketManager: webSocketManager,
                        showCreateWallet: $showCreateWallet
                    )
                }
                
                // Performance and Activity Section
                HStack(alignment: .top, spacing: 20) {
                    // Enhanced Performance Metrics
                    EnhancedPerformanceSection(sniperEngine: sniperEngine)
                    
                    // Recent Activity with Token Feed Preview
                    RecentActivitySection(
                        sniperEngine: sniperEngine,
                        webSocketManager: webSocketManager,
                        onTokenTap: { token in
                            selectedToken = token
                            showTokenDetails = true
                        }
                    )
                }
            }
            .padding()
        }
        .overlay(alignment: .topTrailing) {
            ToastContainer(notificationManager: notificationManager)
                .padding()
        }
        .sheet(isPresented: $showTokenDetails) {
            if let token = selectedToken {
                TokenDetailsView(token: token, walletManager: walletManager)
            }
        }
        .sheet(isPresented: $showSniperSettings) {
            QuickSniperSettingsView(sniperEngine: sniperEngine, walletManager: walletManager)
                .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $showCreateWallet) {
            CreateWalletDialog(
                walletName: $newWalletName,
                isCreating: $isCreatingWallet,
                onCreateWallet: createWallet
            )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animateMetrics = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Computed Properties
    private var totalBalance: Double {
        walletManager.balances.values.reduce(0, +)
    }
    
    private var activeWalletCount: Int {
        walletManager.wallets.filter { $0.isActive }.count
    }
    
    // MARK: - Methods
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
                    showCreateWallet = false
                }
            }
        }
    }
}

// MARK: - Quick Sniper Settings View
struct QuickSniperSettingsView: View {
    @ObservedObject var sniperEngine: SniperEngine
    @ObservedObject var walletManager: WalletManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var sniperConfigs: [SniperConfig]
    @State private var showingDetailedView = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header Stats
                HStack(spacing: 20) {
                    QuickStatCard(
                        title: "Active Configs",
                        value: "\(sniperEngine.activeSnipers.count)",
                        color: .padraigTeal
                    )
                    
                    QuickStatCard(
                        title: "Today's Snipes",
                        value: "\(sniperEngine.todaySnipeCount)",
                        color: .padraigOrange
                    )
                    
                    if let stats = sniperEngine.stats {
                        QuickStatCard(
                            title: "Success Rate",
                            value: "\(Int(stats.successRate))%",
                            color: stats.successRate > 80 ? .padraigTeal : .padraigRed
                        )
                    }
                }
                .padding(.horizontal)
                
                // Quick Configuration Grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(sniperConfigs) { config in
                            CompactConfigCard(
                                config: config,
                                sniperEngine: sniperEngine
                            )
                        }
                        
                        // Add New Config Card
                        Button(action: createNewConfig) {
                            VStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.padraigTeal)
                                
                                Text("New Configuration")
                                    .font(.headline)
                                    .foregroundColor(PadraigTheme.primaryText)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(PadraigTheme.secondaryBackground.opacity(0.5))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.padraigTeal.opacity(0.5), lineWidth: 2)
                                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button("Advanced Settings") {
                        showingDetailedView = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.padraigTeal)
                }
                .padding()
            }
            .navigationTitle("Sniper Settings")
            .background(PadraigTheme.primaryBackground)
        }
        .sheet(isPresented: $showingDetailedView) {
            SniperView(sniperEngine: sniperEngine, walletManager: walletManager)
        }
    }
    
    private func createNewConfig() {
        let newConfig = SniperConfig(name: "New Config \(sniperConfigs.count + 1)")
        modelContext.insert(newConfig)
        try? modelContext.save()
        sniperEngine.loadSniperConfigs()
    }
}

// MARK: - Quick Stat Card
struct QuickStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(PadraigTheme.secondaryBackground)
        )
    }
}

// MARK: - Compact Config Card
struct CompactConfigCard: View {
    @Bindable var config: SniperConfig
    @ObservedObject var sniperEngine: SniperEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(config.name)
                        .font(.headline)
                        .foregroundColor(PadraigTheme.primaryText)
                        .lineLimit(1)
                    
                    Text(config.enabled ? "ACTIVE" : "DISABLED")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(config.enabled ? .padraigTeal : .gray)
                }
                
                Spacer()
                
                Toggle("", isOn: $config.enabled)
                    .toggleStyle(.switch)
                    .scaleEffect(0.8)
                    .onChange(of: config.enabled) { _, newValue in
                        config.lastUpdated = Date()
                        try? config.modelContext?.save()
                        sniperEngine.updateSniperConfig(config)
                    }
            }
            
            // Quick Stats
            HStack {
                Label("\(config.keywords.count)", systemImage: "textformat")
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
                
                Label("\(config.selectedWallets.count)", systemImage: "wallet.pass")
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
                
                if !config.twitterAccounts.isEmpty {
                    Label("\(config.twitterAccounts.count)", systemImage: "at")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
            }
            
            // Buy Amount
            Text("\(config.buyAmount.formatted(.number.precision(.fractionLength(3)))) SOL")
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(config.enabled ? PadraigTheme.secondaryBackground : PadraigTheme.secondaryBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(config.enabled ? Color.padraigTeal.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .frame(minHeight: 120)
    }
}

// MARK: - Dashboard Header
struct DashboardHeader: View {
    @ObservedObject var walletManager: WalletManager
    @ObservedObject var sniperEngine: SniperEngine
    @ObservedObject var webSocketManager: PumpPortalWebSocketManager
    @Binding var showCreateWallet: Bool
    @Binding var showSniperSettings: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("PadraigAIO Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(PadraigTheme.primaryText)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(systemStatusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(systemStatusText)
                        .font(.subheadline)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
            }
            
            Spacer()
            
            // Quick Action Buttons
            HStack(spacing: 12) {
                Button("Create Wallet") {
                    showCreateWallet = true
                }
                .buttonStyle(.bordered)
                
                Button("Sniper Settings") {
                    showSniperSettings = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.padraigTeal)
            }
        }
    }
    
    private var systemStatusColor: Color {
        if sniperEngine.isActive && webSocketManager.isConnected {
            return .padraigTeal
        } else if webSocketManager.isConnected {
            return .padraigOrange
        } else {
            return .gray
        }
    }
    
    private var systemStatusText: String {
        if sniperEngine.isActive && webSocketManager.isConnected {
            return "System Active - Sniper Running"
        } else if webSocketManager.isConnected {
            return "Connected - Sniper Stopped"
        } else {
            return "Disconnected"
        }
    }
}

// MARK: - Enhanced Dashboard Card
struct EnhancedDashboardCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    @Binding var animate: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                    .scaleEffect(animate ? 1.1 : 1.0)
                
                Spacer()
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
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
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Sniper Control Panel
struct SniperControlPanel: View {
    @ObservedObject var sniperEngine: SniperEngine
    @ObservedObject var webSocketManager: PumpPortalWebSocketManager
    @Binding var showSniperSettings: Bool
    @Binding var animateMetrics: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Sniper Control")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Spacer()
                
                Button(action: { showSniperSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.padraigTeal)
                }
                .buttonStyle(.plain)
            }
            
            // Enhanced Sniper Toggle
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    sniperEngine.toggleSniper(active: !sniperEngine.isActive)
                }
            }) {
                HStack(spacing: 12) {
                    // Icon with background circle
                    ZStack {
                        Circle()
                            .fill(sniperEngine.isActive ? Color.padraigRed : Color.padraigTeal)
                            .frame(width: 60, height: 60)
                            .shadow(color: (sniperEngine.isActive ? Color.padraigRed : Color.padraigTeal).opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: sniperEngine.isActive ? "stop.fill" : "play.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .scaleEffect(animateMetrics && sniperEngine.isActive ? 1.1 : 1.0)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sniperEngine.isActive ? "STOP SNIPER" : "START SNIPER")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(PadraigTheme.primaryText)
                        
                        Text(sniperEngine.isActive ? "Currently monitoring tokens" : "Click to begin monitoring")
                            .font(.caption)
                            .foregroundColor(PadraigTheme.secondaryText)
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    VStack(spacing: 4) {
                        Circle()
                            .fill(sniperEngine.isActive ? Color.padraigTeal : Color.gray)
                            .frame(width: 12, height: 12)
                            .scaleEffect(animateMetrics && sniperEngine.isActive ? 1.2 : 1.0)
                        
                        Text(sniperEngine.isActive ? "ACTIVE" : "INACTIVE")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(sniperEngine.isActive ? .padraigTeal : .gray)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                PadraigTheme.secondaryBackground,
                                PadraigTheme.secondaryBackground.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        (sniperEngine.isActive ? Color.padraigTeal : Color.gray).opacity(0.4),
                                        (sniperEngine.isActive ? Color.padraigTeal : Color.gray).opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
            )
            
            // Quick Stats
            HStack {
                VStack {
                    Text("\(sniperEngine.activeSnipers.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.padraigTeal)
                    Text("Active")
                        .font(.caption2)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("\(sniperEngine.todaySnipeCount)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.padraigOrange)
                    Text("Today")
                        .font(.caption2)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PadraigTheme.secondaryBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Quick Actions Dashboard
struct QuickActionsDashboard: View {
    @ObservedObject var walletManager: WalletManager
    @ObservedObject var webSocketManager: PumpPortalWebSocketManager
    @Binding var showCreateWallet: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Quick Actions")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(PadraigTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionButton(
                    title: "Create Wallet",
                    icon: "plus.circle.fill",
                    color: .padraigRed
                ) {
                    showCreateWallet = true
                }
                
                QuickActionButton(
                    title: webSocketManager.isConnected ? "Stop Feed" : "Start Feed",
                    icon: webSocketManager.isConnected ? "stop.circle" : "play.circle",
                    color: webSocketManager.isConnected ? .padraigRed : .padraigTeal
                ) {
                    if webSocketManager.isConnected {
                        webSocketManager.stopTokenFeed()
                    } else {
                        webSocketManager.startTokenFeed()
                    }
                }
                
                QuickActionButton(
                    title: "Refresh Balances",
                    icon: "arrow.clockwise",
                    color: .blue
                ) {
                    walletManager.updateAllBalances()
                }
                
                QuickActionButton(
                    title: "Clear Feed",
                    icon: "trash",
                    color: .gray
                ) {
                    webSocketManager.clearTokenHistory()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PadraigTheme.secondaryBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(PadraigTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(PadraigTheme.primaryBackground.opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Enhanced Performance Section
struct EnhancedPerformanceSection: View {
    @ObservedObject var sniperEngine: SniperEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(PadraigTheme.primaryText)
            
            if let stats = sniperEngine.stats {
                VStack(spacing: 12) {
                    PerformanceMetricRow(
                        label: "Total Attempts",
                        value: "\(stats.totalAttempts)",
                        icon: "target",
                        color: .blue
                    )
                    
                    PerformanceMetricRow(
                        label: "Successful",
                        value: "\(stats.successfulSnipes)",
                        icon: "checkmark.circle.fill",
                        color: .padraigTeal
                    )
                    
                    PerformanceMetricRow(
                        label: "Average Speed",
                        value: "\(Int(stats.averageSpeed))ms",
                        icon: "speedometer",
                        color: .padraigOrange
                    )
                    
                    PerformanceMetricRow(
                        label: "Total Spent",
                        value: "\(stats.totalSpent.formatted(.number.precision(.fractionLength(2)))) SOL",
                        icon: "dollarsign.circle",
                        color: .padraigRed
                    )
                }
            } else {
                Text("No performance data available")
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
                    .padding(.vertical)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PadraigTheme.secondaryBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Performance Metric Row
struct PerformanceMetricRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(label)
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(PadraigTheme.primaryText)
        }
    }
}

// MARK: - Recent Activity Section
struct RecentActivitySection: View {
    @ObservedObject var sniperEngine: SniperEngine
    @ObservedObject var webSocketManager: PumpPortalWebSocketManager
    let onTokenTap: (TokenCreation) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Spacer()
                
                Text("\(webSocketManager.newTokens.count) tokens")
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
            
            VStack(spacing: 8) {
                // Recent Matches
                if !sniperEngine.recentMatches.isEmpty {
                    ForEach(Array(sniperEngine.recentMatches.suffix(3).reversed()), id: \.id) { match in
                        RecentMatchRow(match: match)
                    }
                }
                
                // Recent Tokens Preview
                if !webSocketManager.newTokens.isEmpty {
                    Divider()
                    
                    Text("Latest Tokens")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(PadraigTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(Array(webSocketManager.newTokens.suffix(3).reversed()), id: \.mint) { token in
                        RecentTokenRow(token: token) {
                            onTokenTap(token)
                        }
                    }
                }
                
                if sniperEngine.recentMatches.isEmpty && webSocketManager.newTokens.isEmpty {
                    Text("No recent activity")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                        .padding(.vertical)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PadraigTheme.secondaryBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Recent Match Row
struct RecentMatchRow: View {
    let match: TokenMatch
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.padraigTeal)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(match.token.symbol) matched")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Text(match.matchReasons.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundColor(PadraigTheme.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(match.timestamp, style: .relative)
                .font(.caption2)
                .foregroundColor(PadraigTheme.secondaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(PadraigTheme.primaryBackground.opacity(0.3))
        .cornerRadius(6)
    }
}

// MARK: - Recent Token Row
struct RecentTokenRow: View {
    let token: TokenCreation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: token.image ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PadraigTheme.primaryBackground)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.caption2)
                                .foregroundColor(PadraigTheme.secondaryText)
                        )
                }
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(token.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(PadraigTheme.primaryText)
                        .lineLimit(1)
                    
                    Text("$\(token.symbol)")
                        .font(.caption2)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                
                Spacer()
                
                Text(token.createdDate, style: .relative)
                    .font(.caption2)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(PadraigTheme.primaryBackground.opacity(0.3))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Token Row View
struct TokenRowView: View {
    let token: TokenCreation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Token Image
                AsyncImage(url: URL(string: token.image ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(PadraigTheme.secondaryBackground)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(PadraigTheme.secondaryText)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Token Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(token.name)
                            .font(.headline)
                            .foregroundColor(PadraigTheme.primaryText)
                        
                        Text("$\(token.symbol)")
                            .font(.caption)
                            .foregroundColor(PadraigTheme.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PadraigTheme.secondaryBackground)
                            .cornerRadius(4)
                    }
                    
                    if let description = token.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(PadraigTheme.secondaryText)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Text(token.createdDate, style: .relative)
                            .font(.caption2)
                            .foregroundColor(PadraigTheme.secondaryText)
                        
                        Spacer()
                        
                        if let supply = token.totalSupply {
                            Text("Supply: \(supply.formatted(.number.precision(.fractionLength(0))))")
                                .font(.caption2)
                                .foregroundColor(PadraigTheme.secondaryText)
                        }
                        
                        if let liquidity = token.initialLiquidity {
                            Text("Liq: \(liquidity.formatted(.number.precision(.fractionLength(2)))) SOL")
                                .font(.caption2)
                                .foregroundColor(PadraigTheme.secondaryText)
                        }
                    }
                }
                
                Spacer()
                
                // Quick Actions
                VStack(spacing: 4) {
                    Button("Buy") {
                        // Quick buy action
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Text(token.mint.prefix(8) + "...")
                        .font(.caption2)
                        .foregroundColor(PadraigTheme.secondaryText)
                        .textSelection(.enabled)
                }
            }
            .padding()
            .background(PadraigTheme.secondaryBackground)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Token Details View
struct TokenDetailsView: View {
    let token: TokenCreation
    @ObservedObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var buyAmount: Double = 0.1
    @State private var slippage: Double = 10.0
    @State private var selectedWallet: Wallet?
    @State private var selectedPool = "pump"
    @State private var isTrading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Token Header
                HStack(spacing: 16) {
                    AsyncImage(url: URL(string: token.image ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(PadraigTheme.secondaryBackground)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(PadraigTheme.secondaryText)
                                    .font(.title)
                            )
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(token.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("$\(token.symbol)")
                            .font(.title3)
                            .foregroundColor(PadraigTheme.secondaryText)
                        
                        Text("Created \(token.createdDate, style: .relative)")
                            .font(.caption)
                            .foregroundColor(PadraigTheme.secondaryText)
                    }
                    
                    Spacer()
                }
                
                // Token Details
                VStack(alignment: .leading, spacing: 12) {
                    if let description = token.description {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.headline)
                            Text(description)
                                .font(.body)
                                .foregroundColor(PadraigTheme.secondaryText)
                        }
                    }
                    
                    HStack(spacing: 40) {
                        VStack(alignment: .leading) {
                            Text("Mint Address")
                                .font(.caption)
                                .foregroundColor(PadraigTheme.secondaryText)
                            Text(token.mint)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        
                        if let supply = token.totalSupply {
                            VStack(alignment: .leading) {
                                Text("Total Supply")
                                    .font(.caption)
                                    .foregroundColor(PadraigTheme.secondaryText)
                                Text("\(supply.formatted(.number.precision(.fractionLength(0))))")
                                    .font(.caption)
                            }
                        }
                        
                        if let liquidity = token.initialLiquidity {
                            VStack(alignment: .leading) {
                                Text("Initial Liquidity")
                                    .font(.caption)
                                    .foregroundColor(PadraigTheme.secondaryText)
                                Text("\(liquidity.formatted(.number.precision(.fractionLength(2)))) SOL")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding()
                .background(PadraigTheme.secondaryBackground)
                .cornerRadius(10)
                
                // Trading Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Trade")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        // Wallet Selection
                        VStack(alignment: .leading) {
                            Text("Wallet")
                                .font(.caption)
                                .foregroundColor(PadraigTheme.secondaryText)
                            
                            Picker("Wallet", selection: $selectedWallet) {
                                Text("Select Wallet").tag(nil as Wallet?)
                                ForEach(walletManager.wallets.filter { $0.isActive }) { wallet in
                                    Text("\(wallet.name) (\(wallet.balance.formatted(.number.precision(.fractionLength(3)))) SOL)")
                                        .tag(wallet as Wallet?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        // Pool Selection
                        VStack(alignment: .leading) {
                            Text("Pool")
                                .font(.caption)
                                .foregroundColor(PadraigTheme.secondaryText)
                            
                            Picker("Pool", selection: $selectedPool) {
                                Text("Pump.fun").tag("pump")
                                Text("Bonk.fun").tag("bonk")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    
                    HStack(spacing: 16) {
                        // Buy Amount
                        VStack(alignment: .leading) {
                            Text("Amount (SOL)")
                                .font(.caption)
                                .foregroundColor(PadraigTheme.secondaryText)
                            
                            TextField("0.1", value: $buyAmount, format: .number)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // Slippage
                        VStack(alignment: .leading) {
                            Text("Slippage (%)")
                                .font(.caption)
                                .foregroundColor(PadraigTheme.secondaryText)
                            
                            TextField("10", value: $slippage, format: .number)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    // Trade Button
                    Button(action: executeTrade) {
                        HStack {
                            if isTrading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isTrading ? "Executing..." : "Buy Token")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedWallet == nil || isTrading || buyAmount <= 0)
                }
                .padding()
                .background(PadraigTheme.secondaryBackground)
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Token Details")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func executeTrade() {
        guard let wallet = selectedWallet else { return }
        
        isTrading = true
        
        Task {
            let result = await walletManager.buyToken(
                mint: token.mint,
                amount: buyAmount,
                slippage: slippage,
                wallet: wallet,
                pool: selectedPool
            )
            
            await MainActor.run {
                isTrading = false
                
                if result.success {
                    NotificationManager.shared.snipeSuccess(token.name, result.signature ?? "")
                } else {
                    NotificationManager.shared.snipeFailure(token.name, result.error ?? "Unknown error")
                }
            }
        }
    }
}

// MARK: - Sniper Configuration View
struct SniperView: View {
    @ObservedObject var sniperEngine: SniperEngine
    @ObservedObject var walletManager: WalletManager
    @Environment(\.modelContext) private var modelContext
    
    @Query private var sniperConfigs: [SniperConfig]
    @State private var selectedConfig: SniperConfig?
    @State private var showConfigEditor = false
    @State private var showQuickView = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Enhanced Header with Toggle
            HStack {
                Text("Sniper Configurations")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Spacer()
                
                // View Toggle
                Picker("View Mode", selection: $showQuickView) {
                    Text("Quick View").tag(true)
                    Text("Detail View").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                Button(action: createNewConfig) {
                    Label("New Config", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.padraigTeal)
            }
            .padding()
            
            Divider()
            
            if showQuickView {
                // Quick Configuration Cards View
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(sniperConfigs) { config in
                            QuickConfigCard(
                                config: config,
                                sniperEngine: sniperEngine,
                                onEdit: {
                                    selectedConfig = config
                                    showQuickView = false
                                }
                            )
                        }
                        
                        // Add New Config Card
                        NewConfigCard(action: createNewConfig)
                    }
                    .padding()
                }
            } else {
                // Detailed Configuration View
                HSplitView {
                    // Config List
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Configurations")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: createNewConfig) {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                        
                        List(sniperConfigs, selection: $selectedConfig) { config in
                            EnhancedSniperConfigRowView(config: config, sniperEngine: sniperEngine)
                                .tag(config)
                        }
                        .listStyle(.sidebar)
                    }
                    .frame(minWidth: 280)
                    
                    // Config Details
                    Group {
                        if let config = selectedConfig {
                            SniperConfigDetailView(
                                config: config,
                                walletManager: walletManager,
                                sniperEngine: sniperEngine
                            )
                        } else {
                            ContentUnavailableView(
                                "Select Configuration",
                                systemImage: "target",
                                description: Text("Choose a sniper configuration to view details")
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func createNewConfig() {
        let newConfig = SniperConfig(name: "New Config \(sniperConfigs.count + 1)")
        modelContext.insert(newConfig)
        try? modelContext.save()
        selectedConfig = newConfig
        sniperEngine.loadSniperConfigs()
    }
}

// MARK: - Quick Config Card
struct QuickConfigCard: View {
    @Bindable var config: SniperConfig
    @ObservedObject var sniperEngine: SniperEngine
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(config.name)
                        .font(.headline)
                        .foregroundColor(PadraigTheme.primaryText)
                        .lineLimit(1)
                    
                    Text(config.enabled ? "ACTIVE" : "DISABLED")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(config.enabled ? .padraigTeal : .gray)
                }
                
                Spacer()
                
                Toggle("", isOn: $config.enabled)
                    .toggleStyle(.switch)
                    .scaleEffect(0.8)
                    .onChange(of: config.enabled) { _, newValue in
                        config.lastUpdated = Date()
                        try? config.modelContext?.save()
                        sniperEngine.updateSniperConfig(config)
                    }
            }
            
            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                StatItem(label: "Keywords", value: "\(config.keywords.count)")
                StatItem(label: "Wallets", value: "\(config.selectedWallets.count)")
                StatItem(label: "Amount", value: "\(config.buyAmount.formatted(.number.precision(.fractionLength(2))))sol")
                StatItem(label: "Twitter", value: "\(config.twitterAccounts.count)")
            }
            
            // Action Buttons
            HStack(spacing: 8) {
                Button("Edit") {
                    onEdit()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                
                Button("Test") {
                    sniperEngine.testTokenProcessing()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(config.enabled ? PadraigTheme.secondaryBackground : PadraigTheme.secondaryBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(config.enabled ? Color.padraigTeal.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .frame(height: 160)
    }
}

// MARK: - New Config Card
struct NewConfigCard: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.padraigTeal)
                
                Text("New Configuration")
                    .font(.headline)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Text("Create a new sniper config")
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(PadraigTheme.secondaryBackground.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.padraigTeal.opacity(0.5), lineWidth: 2)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    )
            )
        }
        .buttonStyle(.plain)
        .frame(height: 160)
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(PadraigTheme.primaryText)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(PadraigTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(PadraigTheme.primaryBackground.opacity(0.5))
        .cornerRadius(6)
    }
}

// MARK: - Enhanced Sniper Config Row
struct EnhancedSniperConfigRowView: View {
    @Bindable var config: SniperConfig
    @ObservedObject var sniperEngine: SniperEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(config.name)
                    .font(.headline)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Spacer()
                
                Toggle("", isOn: $config.enabled)
                    .toggleStyle(.switch)
                    .scaleEffect(0.8)
                    .onChange(of: config.enabled) { _, newValue in
                        config.lastUpdated = Date()
                        try? config.modelContext?.save()
                        sniperEngine.updateSniperConfig(config)
                    }
            }
            
            HStack {
                Label("\(config.keywords.count)", systemImage: "textformat")
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
                
                Label("\(config.selectedWallets.count)", systemImage: "wallet.pass")
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
                
                Label("\(config.twitterAccounts.count)", systemImage: "at")
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
            
            Text("\(config.buyAmount.formatted(.number.precision(.fractionLength(3)))) SOL per wallet")
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Legacy Sniper Config Row (for compatibility)
struct SniperConfigRowView: View {
    var config: SniperConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(config.name)
                    .font(.headline)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Spacer()
                
                if config.enabled {
                    Circle()
                        .fill(Color.padraigTeal)
                        .frame(width: 8, height: 8)
                }
            }
            
            Text("\(config.keywords.count) keywords, \(config.selectedWallets.count) wallets")
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
            
            Text("\(config.buyAmount.formatted(.number.precision(.fractionLength(3)))) SOL per wallet")
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sniper Config Detail View
struct SniperConfigDetailView: View {
    @Bindable var config: SniperConfig
    @ObservedObject var walletManager: WalletManager
    @ObservedObject var sniperEngine: SniperEngine
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    TextField("Config Name", text: $config.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .textFieldStyle(.plain)
                    
                    Spacer()
                    
                    Toggle("Enabled", isOn: $config.enabled)
                        .toggleStyle(.switch)
                }
                
                // Criteria Section
                GroupBox("Filter Criteria") {
                    VStack(alignment: .leading, spacing: 12) {
                        KeywordEditor(keywords: $config.keywords, title: "Keywords")
                        KeywordEditor(keywords: $config.blacklist, title: "Blacklist")
                        KeywordEditor(keywords: $config.twitterAccounts, title: "Twitter Accounts")
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Min Liquidity (SOL)")
                                    .font(.caption)
                                TextField("5.0", value: $config.minLiquidity, format: .number)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Max Supply")
                                    .font(.caption)
                                TextField("1000000000", value: $config.maxSupply, format: .number)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Creator Address (optional)")
                                .font(.caption)
                            TextField("Solana address", text: Binding(
                                get: { config.creatorAddress ?? "" },
                                set: { config.creatorAddress = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                
                // Trading Settings
                GroupBox("Trading Settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Buy Amount (SOL)")
                                    .font(.caption)
                                TextField("0.1", value: $config.buyAmount, format: .number)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Slippage (%)")
                                    .font(.caption)
                                TextField("10", value: $config.slippage, format: .number)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Max Gas (SOL)")
                                    .font(.caption)
                                TextField("0.01", value: $config.maxGas, format: .number)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Stagger Delay (ms)")
                                    .font(.caption)
                                TextField("100", value: $config.staggerDelay, format: .number)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Trading Pool")
                                .font(.caption)
                            Picker("Pool", selection: $config.tradingPool) {
                                Text("Pump.fun").tag("pump")
                                Text("Bonk.fun").tag("bonk")
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Wallet Selection
                        VStack(alignment: .leading) {
                            Text("Active Wallets")
                                .font(.caption)
                            
                            ForEach(walletManager.wallets.filter { $0.isActive }) { wallet in
                                HStack {
                                    Toggle(isOn: Binding(
                                        get: { config.selectedWallets.contains(wallet.id) },
                                        set: { isSelected in
                                            if isSelected {
                                                config.selectedWallets.append(wallet.id)
                                            } else {
                                                config.selectedWallets.removeAll { $0 == wallet.id }
                                            }
                                        }
                                    )) {
                                        Text("\(wallet.name) (\(wallet.balance.formatted(.number.precision(.fractionLength(3)))) SOL)")
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Safety Settings
                GroupBox("Safety Settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Max Daily Spend (SOL)")
                                    .font(.caption)
                                TextField("1.0", value: $config.maxDailySpend, format: .number)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Cooldown Period (s)")
                                    .font(.caption)
                                TextField("30", value: $config.cooldownPeriod, format: .number)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        Toggle("Require Manual Confirmation", isOn: $config.requireConfirmation)
                    }
                }
            }
            .padding()
        }
        .onChange(of: config) { _, newValue in
            newValue.lastUpdated = Date()
            try? newValue.modelContext?.save()
            sniperEngine.updateSniperConfig(newValue)
        }
    }
}

// MARK: - Keyword Editor
struct KeywordEditor: View {
    @Binding var keywords: [String]
    let title: String
    @State private var newKeyword = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
            
            // Add new keyword
            HStack {
                TextField("Add \(title.lowercased())", text: $newKeyword)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addKeyword()
                    }
                
                Button("Add") {
                    addKeyword()
                }
                .buttonStyle(.bordered)
                .disabled(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            // Existing keywords
            if !keywords.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                    ForEach(keywords, id: \.self) { keyword in
                        HStack {
                            Text(keyword)
                                .font(.caption)
                            
                            Button(action: {
                                keywords.removeAll { $0 == keyword }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.padraigTeal.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    private func addKeyword() {
        let trimmed = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !keywords.contains(trimmed) {
            keywords.append(trimmed)
            newKeyword = ""
        }
    }
}