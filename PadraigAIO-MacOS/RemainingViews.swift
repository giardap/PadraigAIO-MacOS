//
//  RemainingViews.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/24/25.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Wallet Management View
struct WalletView: View {
    @ObservedObject var walletManager: WalletManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var showCreateWallet = false
    @State private var showImportWallet = false
    @State private var selectedWallet: Wallet?
    @State private var showWalletDetails = false
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Wallet Management")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(walletManager.wallets.count) wallets • \(String(format: "%.4f", totalBalance)) SOL total")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 12) {
                    Button(action: refreshBalances) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRefreshing)
                    
                    Button(action: { showImportWallet = true }) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { showCreateWallet = true }) {
                        Label("Create", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            
            Divider()
            
            // Wallet List
            if walletManager.wallets.isEmpty {
                ContentUnavailableView(
                    "No Wallets",
                    systemImage: "wallet.pass",
                    description: Text("Create or import a wallet to get started")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(walletManager.wallets) { wallet in
                        WalletRowView(wallet: wallet, walletManager: walletManager) {
                            selectedWallet = wallet
                            showWalletDetails = true
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await refreshAllBalances()
                }
            }
        }
        .sheet(isPresented: $showCreateWallet) {
            CreateWalletView(walletManager: walletManager)
        }
        .sheet(isPresented: $showImportWallet) {
            ImportWalletView(walletManager: walletManager)
        }
        .sheet(isPresented: $showWalletDetails) {
            if let wallet = selectedWallet {
                WalletDetailView(wallet: wallet, walletManager: walletManager)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var totalBalance: Double {
        walletManager.balances.values.reduce(0, +)
    }
    
    private func refreshBalances() {
        isRefreshing = true
        Task {
            await refreshAllBalances()
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
    
    private func refreshAllBalances() async {
        walletManager.updateAllBalances()
    }
}

// MARK: - Wallet Row View
struct WalletRowView: View {
    var wallet: Wallet
    @ObservedObject var walletManager: WalletManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Status Indicator
                Circle()
                    .fill(wallet.isActive ? Color.padraigTeal : PadraigTheme.secondaryText)
                    .frame(width: 12, height: 12)
                
                // Wallet Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(wallet.name)
                        .font(.headline)
                        .foregroundColor(PadraigTheme.primaryText)
                    
                    Text(wallet.publicKey.prefix(8) + "..." + wallet.publicKey.suffix(8))
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                        .textSelection(.enabled)
                    
                    Text("Last updated: \(wallet.lastUpdated, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                
                Spacer()
                
                // Balance
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(wallet.balance.formatted(.number.precision(.fractionLength(4)))) SOL")
                        .font(.headline)
                        .foregroundColor(PadraigTheme.primaryText)
                    
                    let usdValue = wallet.balance * 20 // Mock SOL price
                    if usdValue > 0 {
                        Text("≈ $\(usdValue.formatted(.number.precision(.fractionLength(2))))")
                            .font(.caption)
                            .foregroundColor(PadraigTheme.secondaryText)
                    }
                }
                
                // Quick Actions
                VStack(spacing: 8) {
                    Button(action: {
                        toggleWalletActive()
                    }) {
                        Image(systemName: wallet.isActive ? "pause.circle" : "play.circle")
                            .foregroundColor(wallet.isActive ? .padraigOrange : .padraigTeal)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        copyPublicKey()
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.padraigTeal)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(PadraigTheme.secondaryBackground)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    private func toggleWalletActive() {
        wallet.isActive.toggle()
        try? wallet.modelContext?.save()
    }
    
    private func copyPublicKey() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(wallet.publicKey, forType: .string)
        NotificationManager.shared.info("Copied", "Public key copied to clipboard")
    }
}

// MARK: - Create Wallet View
struct CreateWalletView: View {
    @ObservedObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var walletName = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create New Wallet")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Wallet Name")
                        .font(.headline)
                    
                    TextField("My Wallet", text: $walletName)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button(action: createWallet) {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isCreating ? "Creating..." : "Create Wallet")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(walletName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Wallet")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createWallet() {
        isCreating = true
        
        Task {
            let success = await walletManager.createWallet(name: walletName.trimmingCharacters(in: .whitespacesAndNewlines))
            
            await MainActor.run {
                isCreating = false
                
                if success {
                    NotificationManager.shared.success("Wallet Created", "\(walletName) created successfully")
                    dismiss()
                } else {
                    NotificationManager.shared.error("Creation Failed", walletManager.lastError ?? "Unknown error")
                }
            }
        }
    }
}

// MARK: - Import Wallet View
struct ImportWalletView: View {
    @ObservedObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var walletName = ""
    @State private var privateKey = ""
    @State private var isImporting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Import Wallet")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Wallet Name")
                        .font(.headline)
                    
                    TextField("Imported Wallet", text: $walletName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Private Key")
                        .font(.headline)
                    
                    SecureField("Enter private key", text: $privateKey)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Your private key will be securely stored in the macOS Keychain")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                
                Button(action: importWallet) {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isImporting ? "Importing..." : "Import Wallet")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(walletName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                         privateKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Import Wallet")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func importWallet() {
        isImporting = true
        
        Task {
            let success = await walletManager.importWallet(
                name: walletName.trimmingCharacters(in: .whitespacesAndNewlines),
                privateKey: privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            await MainActor.run {
                isImporting = false
                
                if success {
                    NotificationManager.shared.success("Wallet Imported", "\(walletName) imported successfully")
                    dismiss()
                } else {
                    NotificationManager.shared.error("Import Failed", walletManager.lastError ?? "Unknown error")
                }
            }
        }
    }
}

// MARK: - Wallet Detail View
struct WalletDetailView: View {
    var wallet: Wallet
    @ObservedObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showPrivateKey = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Wallet Header
                VStack(spacing: 12) {
                    Text(wallet.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(String(format: "%.4f SOL", wallet.balance))
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(PadraigTheme.primaryText)
                    
                    Text(String(format: "≈ $%.2f", wallet.balance * 20))
                        .font(.headline)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                .padding()
                .background(PadraigTheme.secondaryBackground)
                .cornerRadius(12)
                
                // Wallet Info
                VStack(alignment: .leading, spacing: 16) {
                    InfoRow(title: "Public Key", value: wallet.publicKey, copyable: true)
                    InfoRow(title: "Status", value: wallet.isActive ? "Active" : "Inactive")
                    InfoRow(title: "Created", value: wallet.createdAt.formatted(date: .abbreviated, time: .shortened))
                    InfoRow(title: "Last Updated", value: wallet.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                }
                .padding()
                .background(PadraigTheme.secondaryBackground)
                .cornerRadius(12)
                
                // Actions
                VStack(spacing: 12) {
                    Button(action: {
                        showPrivateKey.toggle()
                    }) {
                        Label(showPrivateKey ? "Hide Private Key" : "Show Private Key", 
                              systemImage: showPrivateKey ? "eye.slash" : "eye")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    if showPrivateKey {
                        if let privateKey = walletManager.exportPrivateKey(for: wallet) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Private Key")
                                    .font(.headline)
                                    .foregroundColor(.padraigRed)
                                
                                Text(privateKey)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding()
                                    .background(Color.padraigRed.opacity(0.1))
                                    .cornerRadius(8)
                                
                                Text("⚠️ Never share your private key with anyone!")
                                    .font(.caption)
                                    .foregroundColor(.padraigRed)
                            }
                        }
                    }
                    
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Label("Delete Wallet", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.padraigRed)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Wallet Details")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog("Delete Wallet", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                walletManager.deleteWallet(wallet)
                dismiss()
            }
        } message: {
            Text("This action cannot be undone. Make sure you have backed up your private key.")
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let title: String
    let value: String
    let copyable: Bool
    
    init(title: String, value: String, copyable: Bool = false) {
        self.title = title
        self.value = value
        self.copyable = copyable
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
                .frame(width: 100, alignment: .leading)
            
            if copyable {
                Text(value)
                    .font(.caption)
                    .textSelection(.enabled)
            } else {
                Text(value)
                    .font(.caption)
            }
            
            Spacer()
            
            if copyable {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                    NotificationManager.shared.info("Copied", "\(title) copied to clipboard")
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Transaction History View
struct TransactionView: View {
    let transactions: [TransactionRecord]
    
    @State private var searchText = ""
    @State private var selectedType = "All"
    @State private var sortOrder = "Newest"
    
    private let transactionTypes = ["All", "Buy", "Sell", "Failed"]
    private let sortOptions = ["Newest", "Oldest", "Amount (High)", "Amount (Low)"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header and Filters
            VStack(spacing: 12) {
                HStack {
                    Text("Transaction History")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text("\(filteredTransactions.count) transactions")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                
                HStack(spacing: 12) {
                    TextField("Search transactions...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(transactionTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(sortOptions, id: \.self) { sort in
                            Text(sort).tag(sort)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
            }
            .padding()
            
            Divider()
            
            // Transaction List
            if filteredTransactions.isEmpty {
                ContentUnavailableView(
                    "No Transactions",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Your transaction history will appear here")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredTransactions) { transaction in
                    TransactionRowView(transaction: transaction)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var filteredTransactions: [TransactionRecord] {
        var filtered = transactions
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.tokenName.localizedCaseInsensitiveContains(searchText) ||
                $0.tokenSymbol.localizedCaseInsensitiveContains(searchText) ||
                $0.txSignature?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Filter by type
        if selectedType != "All" {
            filtered = filtered.filter {
                switch selectedType {
                case "Buy":
                    return $0.transactionType == "buy" && $0.success
                case "Sell":
                    return $0.transactionType == "sell" && $0.success
                case "Failed":
                    return !$0.success
                default:
                    return true
                }
            }
        }
        
        // Sort
        switch sortOrder {
        case "Newest":
            filtered = filtered.sorted { $0.timestamp > $1.timestamp }
        case "Oldest":
            filtered = filtered.sorted { $0.timestamp < $1.timestamp }
        case "Amount (High)":
            filtered = filtered.sorted { $0.amount > $1.amount }
        case "Amount (Low)":
            filtered = filtered.sorted { $0.amount < $1.amount }
        default:
            break
        }
        
        return filtered
    }
}

// MARK: - Transaction Row View
struct TransactionRowView: View {
    let transaction: TransactionRecord
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Status Icon
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.title2)
                
                // Transaction Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(transaction.tokenName)
                            .font(.headline)
                        
                        Text("$\(transaction.tokenSymbol)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PadraigTheme.secondaryBackground)
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Text(transaction.transactionType.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(typeColor.opacity(0.2))
                            .foregroundColor(typeColor)
                            .cornerRadius(4)
                    }
                    
                    Text(transaction.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                
                // Amount
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(transaction.amount.formatted(.number.precision(.fractionLength(4)))) SOL")
                        .font(.headline)
                        .foregroundColor(PadraigTheme.primaryText)
                    
                    if transaction.success {
                        Text("Price: \(transaction.price.formatted(.number.precision(.fractionLength(6))))")
                            .font(.caption)
                            .foregroundColor(PadraigTheme.secondaryText)
                    }
                    
                    Text("Gas: \(transaction.gasUsed.formatted(.number.precision(.fractionLength(6))))")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
            }
            
            // Transaction Signature
            if let signature = transaction.txSignature {
                HStack {
                    Text("Tx: \(signature.prefix(8))...\(signature.suffix(8))")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                        .textSelection(.enabled)
                    
                    Spacer()
                    
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(signature, forType: .string)
                        NotificationManager.shared.info("Copied", "Transaction signature copied")
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
            }
            
            // Error Message
            if !transaction.success, let error = transaction.errorMessage {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.padraigRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(10)
    }
    
    private var statusIcon: String {
        transaction.success ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    private var statusColor: Color {
        transaction.success ? .padraigTeal : .padraigRed
    }
    
    private var typeColor: Color {
        switch transaction.transactionType {
        case "buy":
            return .padraigTeal
        case "sell":
            return .padraigOrange
        default:
            return PadraigTheme.secondaryText
        }
    }
}

// MARK: - Analytics View
struct AnalyticsView: View {
    @ObservedObject var walletManager: WalletManager
    @ObservedObject var sniperEngine: SniperEngine
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Portfolio Overview
                PortfolioOverviewCard(walletManager: walletManager)
                
                // Sniper Performance
                SniperPerformanceCard(sniperEngine: sniperEngine)
                
                // Wallet Distribution
                WalletDistributionCard(walletManager: walletManager)
                
                // Recent Activity
                RecentActivityCard(sniperEngine: sniperEngine)
            }
            .padding()
        }
        .navigationTitle("Analytics")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Portfolio Overview Card
struct PortfolioOverviewCard: View {
    @ObservedObject var walletManager: WalletManager
    
    var body: some View {
        GroupBox("Portfolio Overview") {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total Balance")
                            .font(.caption)
                            .foregroundColor(PadraigTheme.secondaryText)
                        Text(String(format: "%.4f SOL", totalBalance))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(String(format: "≈ $%.2f", totalBalance * 20))
                            .font(.caption)
                            .foregroundColor(PadraigTheme.secondaryText)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Active Wallets")
                            .font(.caption)
                            .foregroundColor(PadraigTheme.secondaryText)
                        Text("\(activeWalletCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("of \(walletManager.wallets.count)")
                            .font(.caption)
                            .foregroundColor(PadraigTheme.secondaryText)
                    }
                }
            }
        }
    }
    
    private var totalBalance: Double {
        walletManager.balances.values.reduce(0, +)
    }
    
    private var activeWalletCount: Int {
        walletManager.wallets.filter { $0.isActive }.count
    }
}

// MARK: - Sniper Performance Card
struct SniperPerformanceCard: View {
    @ObservedObject var sniperEngine: SniperEngine
    
    var body: some View {
        GroupBox("Sniper Performance") {
            VStack(spacing: 16) {
                if let stats = sniperEngine.stats {
                    HStack {
                        StatItem(label: "Success Rate", value: "\(stats.successRate.formatted(.number.precision(.fractionLength(1))))%")
                        StatItem(label: "Total Snipes", value: "\(stats.totalAttempts)")
                        StatItem(label: "Average Speed", value: "\(stats.averageSpeed.formatted(.number.precision(.fractionLength(0))))ms")
                    }
                    
                    HStack {
                        StatItem(label: "Total Spent", value: "\(stats.totalSpent.formatted(.number.precision(.fractionLength(3)))) SOL")
                        StatItem(label: "Today's Snipes", value: "\(sniperEngine.todaySnipeCount)")
                        StatItem(label: "Daily Spent", value: "\(stats.dailySpent.formatted(.number.precision(.fractionLength(3)))) SOL")
                    }
                } else {
                    Text("No sniper statistics available")
                        .foregroundColor(PadraigTheme.secondaryText)
                }
            }
        }
    }
}


// MARK: - Wallet Distribution Card
struct WalletDistributionCard: View {
    @ObservedObject var walletManager: WalletManager
    
    var body: some View {
        GroupBox("Wallet Distribution") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(walletManager.wallets.prefix(5)) { wallet in
                    HStack {
                        Circle()
                            .fill(wallet.isActive ? Color.padraigTeal : PadraigTheme.secondaryText)
                            .frame(width: 8, height: 8)
                        
                        Text(wallet.name)
                            .font(.caption)
                        
                        Spacer()
                        
                        Text("\(wallet.balance.formatted(.number.precision(.fractionLength(3)))) SOL")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("(\(walletPercentage(wallet).formatted(.number.precision(.fractionLength(1))))%)")
                            .font(.caption)
                            .foregroundColor(PadraigTheme.secondaryText)
                    }
                }
                
                if walletManager.wallets.count > 5 {
                    Text("... and \(walletManager.wallets.count - 5) more")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
            }
        }
    }
    
    private func walletPercentage(_ wallet: Wallet) -> Double {
        let total = walletManager.balances.values.reduce(0, +)
        guard total > 0 else { return 0 }
        return (wallet.balance / total) * 100
    }
}

// MARK: - Recent Activity Card
struct RecentActivityCard: View {
    @ObservedObject var sniperEngine: SniperEngine
    
    var body: some View {
        GroupBox("Recent Token Matches") {
            VStack(alignment: .leading, spacing: 12) {
                if sniperEngine.recentMatches.isEmpty {
                    Text("No recent matches")
                        .foregroundColor(PadraigTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(sniperEngine.recentMatches.prefix(5)) { match in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(match.token.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Text(match.matchReasons.joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundColor(PadraigTheme.secondaryText)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Score: \(match.score.formatted(.number.precision(.fractionLength(0))))")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                
                                Text(match.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(PadraigTheme.secondaryText)
                            }
                        }
                    }
                }
            }
        }
    }
}