//
//  ModernViews.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/24/25.
//

import SwiftUI
import SwiftData

// MARK: - Modern Token Feed
struct ModernTokenFeed: View {
    @ObservedObject var webSocketManager: PumpPortalWebSocketManager
    @ObservedObject var walletManager: WalletManager
    
    @State private var selectedToken: TokenCreation?
    @State private var showTokenDetails = false
    @State private var searchText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Live Token Feed")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("\(filteredTokens.count) tokens • \(webSocketManager.isConnected ? "Live" : "Offline")")
                        .font(.headline)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 12) {
                    TextField("Search tokens...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                    
                    Button("Clear Feed") {
                        webSocketManager.clearTokenHistory()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            
            Divider()
            
            // Token Grid
            if filteredTokens.isEmpty {
                ContentUnavailableView(
                    webSocketManager.isConnected ? "No Tokens Yet" : "Feed Offline",
                    systemImage: webSocketManager.isConnected ? "antenna.radiowaves.left.and.right" : "wifi.slash",
                    description: Text(webSocketManager.isConnected ? "Waiting for new tokens..." : "Start the feed to see live tokens")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(filteredTokens, id: \.mint) { token in
                            ModernTokenCard(token: token) {
                                selectedToken = token
                                showTokenDetails = true
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showTokenDetails) {
            if let token = selectedToken {
                ModernTokenDetailView(token: token, walletManager: walletManager)
            }
        }
    }
    
    private var filteredTokens: [TokenCreation] {
        if searchText.isEmpty {
            return webSocketManager.newTokens.reversed()
        } else {
            return webSocketManager.newTokens.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.symbol.localizedCaseInsensitiveContains(searchText) ||
                $0.description?.localizedCaseInsensitiveContains(searchText) == true
            }.reversed()
        }
    }
}

// MARK: - Modern Token Card
struct ModernTokenCard: View {
    let token: TokenCreation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
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
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(token.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text("$\(token.symbol)")
                            .font(.caption)
                            .foregroundColor(PadraigTheme.secondaryText)
                    }
                    
                    Spacer()
                    
                    Text(token.createdDate, style: .relative)
                        .font(.caption2)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                
                // Description
                if let description = token.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                        .lineLimit(2)
                }
                
                // Stats
                HStack {
                    if let supply = token.totalSupply {
                        Label("\(supply.formatted(.number.notation(.compactName)))", systemImage: "number")
                            .font(.caption2)
                            .foregroundColor(PadraigTheme.secondaryText)
                    }
                    
                    Spacer()
                    
                    if let liquidity = token.initialLiquidity {
                        Label("\(liquidity.formatted(.number.precision(.fractionLength(2)))) SOL", systemImage: "drop")
                            .font(.caption2)
                            .foregroundColor(.padraigTeal)
                    }
                }
            }
            .padding()
            .background(PadraigTheme.secondaryBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(PadraigTheme.secondaryText.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modern Token Detail View
struct ModernTokenDetailView: View {
    let token: TokenCreation
    @ObservedObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var buyAmount: Double = 0.1
    @State private var slippage: Double = 10.0
    @State private var selectedWallet: Wallet?
    @State private var selectedPool = "pump"
    @State private var isTrading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text(token.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Spacer()
                
                // Invisible button for balance
                Button("") { }
                    .disabled(true)
                    .opacity(0)
            }
            .padding()
            .background(PadraigTheme.secondaryBackground)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Token Header
                    VStack(spacing: 16) {
                        AsyncImage(url: URL(string: token.image ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(PadraigTheme.secondaryBackground)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(PadraigTheme.secondaryText)
                                        .font(.largeTitle)
                                )
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        VStack(spacing: 8) {
                            Text(token.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Text("$\(token.symbol)")
                                .font(.title3)
                                .foregroundColor(PadraigTheme.secondaryText)
                            
                            Text("Created \(token.createdDate, style: .relative)")
                                .font(.caption)
                                .foregroundColor(PadraigTheme.secondaryText)
                        }
                    }
                    
                    // Token Info
                    GroupBox("Token Information") {
                        VStack(alignment: .leading, spacing: 12) {
                            if let description = token.description {
                                InfoSection(title: "Description", content: description)
                            }
                            
                            InfoSection(title: "Mint Address", content: token.mint)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                if let supply = token.totalSupply {
                                    InfoColumn(title: "Total Supply", value: supply.formatted(.number.notation(.compactName)))
                                }
                                
                                if let liquidity = token.initialLiquidity {
                                    InfoColumn(title: "Initial Liquidity", value: "\(liquidity.formatted(.number.precision(.fractionLength(2)))) SOL")
                                }
                                
                                if let creator = token.creator {
                                    InfoColumn(title: "Creator", value: "\(creator.prefix(8))...")
                                }
                            }
                        }
                    }
                    
                    // Trading Section
                    GroupBox("Quick Trade") {
                        VStack(spacing: 16) {
                            // Wallet Selection
                            VStack(alignment: .leading) {
                                Text("Wallet")
                                    .font(.headline)
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
                                    .font(.headline)
                                Picker("Pool", selection: $selectedPool) {
                                    Text("Pump.fun").tag("pump")
                                    Text("Bonk.fun").tag("bonk")
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            // Amount and Slippage
                            HStack(spacing: 16) {
                                VStack(alignment: .leading) {
                                    Text("Amount (SOL)")
                                        .font(.headline)
                                    TextField("0.1", value: $buyAmount, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("Slippage (%)")
                                        .font(.headline)
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
                                    Text(isTrading ? "Executing Trade..." : "Buy \(token.symbol)")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(selectedWallet == nil || isTrading || buyAmount <= 0)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 700)
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
                    dismiss()
                } else {
                    NotificationManager.shared.snipeFailure(token.name, result.error ?? "Unknown error")
                }
            }
        }
    }
}

// MARK: - Info Section
struct InfoSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
            Text(content)
                .font(.body)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Info Column
struct InfoColumn: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Modern Wallet View
struct ModernWalletView: View {
    @ObservedObject var walletManager: WalletManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var showCreateWallet = false
    @State private var showImportWallet = false
    @State private var selectedWallet: Wallet?
    @State private var showWalletDetails = false
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Wallet Management")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("\(walletManager.wallets.count) wallets • \(totalBalance.formatted(.number.precision(.fractionLength(4)))) SOL total")
                        .font(.headline)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button("Refresh Balances") {
                        refreshBalances()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRefreshing)
                    
                    Button("Import Wallet") {
                        showImportWallet = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Create Wallet") {
                        showCreateWallet = true
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
                    description: Text("Create or import a wallet to start trading")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(walletManager.wallets) { wallet in
                            ModernWalletCard(wallet: wallet, walletManager: walletManager) {
                                selectedWallet = wallet
                                showWalletDetails = true
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showCreateWallet) {
            ModernCreateWalletView(walletManager: walletManager)
        }
        .sheet(isPresented: $showImportWallet) {
            ModernImportWalletView(walletManager: walletManager)
        }
        .sheet(isPresented: $showWalletDetails) {
            if let wallet = selectedWallet {
                ModernWalletDetailView(wallet: wallet, walletManager: walletManager)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private var totalBalance: Double {
        walletManager.balances.values.reduce(0, +)
    }
    
    private func refreshBalances() {
        isRefreshing = true
        Task {
            walletManager.updateAllBalances()
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
}

// MARK: - Modern Wallet Card
struct ModernWalletCard: View {
    let wallet: Wallet
    @ObservedObject var walletManager: WalletManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Circle()
                        .fill(wallet.isActive ? Color.padraigTeal : PadraigTheme.secondaryText)
                        .frame(width: 12, height: 12)
                    
                    Text(wallet.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: toggleActive) {
                        Image(systemName: wallet.isActive ? "pause.circle" : "play.circle")
                            .foregroundColor(wallet.isActive ? .padraigOrange : .padraigTeal)
                    }
                    .buttonStyle(.plain)
                }
                
                // Balance
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(wallet.balance.formatted(.number.precision(.fractionLength(4)))) SOL")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("≈ $\((wallet.balance * 20).formatted(.number.precision(.fractionLength(2))))")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                
                // Address
                Text("\(wallet.publicKey.prefix(12))...\(wallet.publicKey.suffix(8))")
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
                    .textSelection(.enabled)
                
                // Last Updated
                Text("Updated \(wallet.lastUpdated, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
            .padding()
            .background(PadraigTheme.secondaryBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(wallet.isActive ? Color.padraigTeal.opacity(0.3) : PadraigTheme.secondaryText.opacity(0.2), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func toggleActive() {
        wallet.isActive.toggle()
        try? wallet.modelContext?.save()
    }
}

// MARK: - Modern Create Wallet View
struct ModernCreateWalletView: View {
    @ObservedObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var walletName = ""
    @State private var isCreating = false
    @State private var error: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text("Create New Wallet")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Invisible button for balance
                Button("") { }
                    .disabled(true)
                    .opacity(0)
            }
            .padding()
            .background(PadraigTheme.secondaryBackground)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Icon and description
                    VStack(spacing: 16) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.padraigTeal)
                        
                        VStack(spacing: 8) {
                            Text("Create New Wallet")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Generate a new Solana wallet with a secure keypair")
                                .font(.body)
                                .foregroundColor(PadraigTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Form
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Wallet Name")
                                .font(.headline)
                            
                            TextField("Enter wallet name", text: $walletName)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        if let error = error {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.padraigRed)
                                Text(error)
                                    .foregroundColor(.padraigRed)
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Create Button
                    Button(action: createWallet) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle")
                            }
                            Text(isCreating ? "Creating Wallet..." : "Create Wallet")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(walletName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                    .controlSize(.large)
                }
                .padding(24)
            }
        }
        .frame(width: 400, height: 500)
    }
    
    private func createWallet() {
        let trimmedName = walletName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        isCreating = true
        error = nil
        
        Task {
            let success = await walletManager.createWallet(name: trimmedName)
            
            await MainActor.run {
                isCreating = false
                
                if success {
                    NotificationManager.shared.success("Wallet Created", "Your new wallet has been created successfully")
                    dismiss()
                } else {
                    error = walletManager.lastError ?? "Failed to create wallet"
                }
            }
        }
    }
}

// MARK: - Modern Import Wallet View  
struct ModernImportWalletView: View {
    @ObservedObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var walletName = ""
    @State private var privateKey = ""
    @State private var isImporting = false
    @State private var error: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text("Import Wallet")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Invisible button for balance
                Button("") { }
                    .disabled(true)
                    .opacity(0)
            }
            .padding()
            .background(PadraigTheme.secondaryBackground)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Icon and description
                    VStack(spacing: 16) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        VStack(spacing: 8) {
                            Text("Import Wallet")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Import an existing Solana wallet using your private key")
                                .font(.body)
                                .foregroundColor(PadraigTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Form
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Wallet Name")
                                .font(.headline)
                            
                            TextField("Enter wallet name", text: $walletName)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Private Key")
                                .font(.headline)
                            
                            SecureField("Enter your private key", text: $privateKey)
                                .textFieldStyle(.roundedBorder)
                            
                            Text("Your private key will be securely stored in the macOS Keychain")
                                .font(.caption)
                                .foregroundColor(PadraigTheme.secondaryText)
                        }
                        
                        if let error = error {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.padraigRed)
                                Text(error)
                                    .foregroundColor(.padraigRed)
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Import Button
                    Button(action: importWallet) {
                        HStack {
                            if isImporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                            }
                            Text(isImporting ? "Importing Wallet..." : "Import Wallet")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(walletName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                             privateKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
                    .controlSize(.large)
                }
                .padding(24)
            }
        }
        .frame(width: 450, height: 550)
    }
    
    private func importWallet() {
        let trimmedName = walletName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty && !trimmedKey.isEmpty else { return }
        
        isImporting = true
        error = nil
        
        Task {
            let success = await walletManager.importWallet(name: trimmedName, privateKey: trimmedKey)
            
            await MainActor.run {
                isImporting = false
                
                if success {
                    NotificationManager.shared.success("Wallet Imported", "Your wallet has been imported successfully")
                    dismiss()
                } else {
                    error = walletManager.lastError ?? "Failed to import wallet"
                }
            }
        }
    }
}

// MARK: - Modern Wallet Detail View
struct ModernWalletDetailView: View {
    let wallet: Wallet
    @ObservedObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showPrivateKey = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text("Wallet Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Invisible button for balance
                Button("") { }
                    .disabled(true)
                    .opacity(0)
            }
            .padding()
            .background(PadraigTheme.secondaryBackground)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Wallet Header
                    VStack(spacing: 16) {
                        Image(systemName: "wallet.pass.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.padraigTeal)
                        
                        Text(wallet.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 8) {
                            Text("\(wallet.balance.formatted(.number.precision(.fractionLength(4)))) SOL")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("≈ $\((wallet.balance * 20).formatted(.number.precision(.fractionLength(2))))")
                                .font(.headline)
                                .foregroundColor(PadraigTheme.secondaryText)
                        }
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(wallet.isActive ? Color.padraigTeal : PadraigTheme.secondaryText)
                                .frame(width: 8, height: 8)
                            Text(wallet.isActive ? "Active" : "Inactive")
                                .font(.caption)
                                .foregroundColor(PadraigTheme.secondaryText)
                        }
                    }
                    
                    // Wallet Details
                    GroupBox("Wallet Information") {
                        VStack(spacing: 16) {
                            DetailRow(title: "Public Key", value: wallet.publicKey, copyable: true)
                            if let apiKey = wallet.apiKey {
                                DetailRow(title: "API Key", value: apiKey, copyable: true)
                            }
                            DetailRow(title: "Created", value: wallet.createdAt.formatted(date: .abbreviated, time: .shortened))
                            DetailRow(title: "Last Updated", value: wallet.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: { showPrivateKey.toggle() }) {
                            Label(showPrivateKey ? "Hide Private Key" : "Show Private Key", 
                                  systemImage: showPrivateKey ? "eye.slash" : "eye")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        if showPrivateKey, let privateKey = walletManager.exportPrivateKey(for: wallet) {
                            GroupBox {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("⚠️ Private Key")
                                        .font(.headline)
                                        .foregroundColor(.padraigRed)
                                    
                                    Text(privateKey)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .padding()
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(8)
                                    
                                    Text("Never share your private key with anyone!")
                                        .font(.caption)
                                        .foregroundColor(.padraigRed)
                                }
                            }
                        }
                        
                        Button(action: { showDeleteAlert = true }) {
                            Label("Delete Wallet", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 450, maxWidth: 450, minHeight: 600, maxHeight: 600)
        .alert("Delete Wallet", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                walletManager.deleteWallet(wallet)
                dismiss()
            }
        } message: {
            Text("This will permanently delete the wallet. Make sure you have backed up your private key.")
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
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
                Button(action: copyValue) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func copyValue() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        NotificationManager.shared.info("Copied", "\(title) copied to clipboard")
    }
}

// MARK: - Modern Transaction View
struct ModernTransactionView: View {
    let transactions: [TransactionRecord]
    
    @State private var searchText = ""
    @State private var filterType = "All"
    @State private var sortOrder = "Newest"
    
    private let filterOptions = ["All", "Buy", "Sell", "Failed"]
    private let sortOptions = ["Newest", "Oldest", "Amount"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Transaction History")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("\(filteredTransactions.count) transactions")
                        .font(.headline)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                
                Spacer()
                
                // Filters
                HStack(spacing: 12) {
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                    
                    Picker("Filter", selection: $filterType) {
                        ForEach(filterOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(sortOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
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
                    ModernTransactionRow(transaction: transaction)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private var filteredTransactions: [TransactionRecord] {
        var filtered = transactions
        
        // Search filter
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.tokenName.localizedCaseInsensitiveContains(searchText) ||
                $0.tokenSymbol.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Type filter
        if filterType != "All" {
            filtered = filtered.filter {
                switch filterType {
                case "Buy": return $0.transactionType == "buy" && $0.success
                case "Sell": return $0.transactionType == "sell" && $0.success
                case "Failed": return !$0.success
                default: return true
                }
            }
        }
        
        // Sort
        switch sortOrder {
        case "Newest": filtered.sort { $0.timestamp > $1.timestamp }
        case "Oldest": filtered.sort { $0.timestamp < $1.timestamp }
        case "Amount": filtered.sort { $0.amount > $1.amount }
        default: break
        }
        
        return filtered
    }
}

// MARK: - Modern Transaction Row
struct ModernTransactionRow: View {
    let transaction: TransactionRecord
    
    var body: some View {
        HStack(spacing: 16) {
            // Status Icon
            Image(systemName: transaction.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(transaction.success ? .padraigTeal : .padraigRed)
                .font(.title2)
            
            // Transaction Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(transaction.tokenName)
                        .font(.headline)
                        .foregroundColor(PadraigTheme.primaryText)
                    
                    Text("$\(transaction.tokenSymbol)")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
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
                
                if !transaction.success, let error = transaction.errorMessage {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.padraigRed)
                }
            }
            
            Spacer()
            
            // Amount and Details
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.amount.formatted(.number.precision(.fractionLength(4)))) SOL")
                    .font(.headline)
                    .fontWeight(.semibold)
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
        .padding()
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
    }
    
    private var typeColor: Color {
        switch transaction.transactionType {
        case "buy": return .padraigTeal
        case "sell": return .padraigOrange
        default: return PadraigTheme.secondaryText
        }
    }
}

// MARK: - Modern Sniper View
struct ModernSniperView: View {
    @ObservedObject var sniperEngine: SniperEngine
    @ObservedObject var walletManager: WalletManager
    @Environment(\.modelContext) private var modelContext
    
    @Query private var sniperConfigs: [SniperConfig]
    @State private var selectedConfig: SniperConfig?
    @State private var showCreateConfig = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Config List
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Sniper Configs")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(PadraigTheme.primaryText)
                    
                    Spacer()
                    
                    Button(action: { showCreateConfig = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.padraigTeal)
                    }
                    .buttonStyle(.plain)
                }
                
                if sniperConfigs.isEmpty {
                    ContentUnavailableView(
                        "No Configs",
                        systemImage: "target",
                        description: Text("Create a sniper configuration to get started")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sniperConfigs) { config in
                                Button(action: {
                                    selectedConfig = config
                                }) {
                                    ModernSniperConfigRow(config: config, isSelected: selectedConfig?.id == config.id)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .frame(minWidth: 300, maxWidth: 400)
            .padding()
            
            Divider()
            
            // Config Details
            Group {
                if let config = selectedConfig {
                    ModernSniperConfigDetail(
                        config: config,
                        walletManager: walletManager,
                        sniperEngine: sniperEngine
                    )
                } else {
                    ContentUnavailableView(
                        "Select Configuration",
                        systemImage: "target",
                        description: Text("Choose a sniper config to view and edit settings")
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showCreateConfig) {
            ModernCreateConfigView()
        }
    }
}

// MARK: - Modern Sniper Config Row
struct ModernSniperConfigRow: View {
    let config: SniperConfig
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(config.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Spacer()
                
                if config.enabled {
                    Circle()
                        .fill(Color.padraigTeal)
                        .frame(width: 8, height: 8)
                }
            }
            
            Text("\(config.keywords.count) keywords • \(config.selectedWallets.count) wallets")
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
            
            Text("\(config.buyAmount.formatted(.number.precision(.fractionLength(3)))) SOL per wallet")
                .font(.caption)
                .foregroundColor(PadraigTheme.secondaryText)
        }
        .padding(12)
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.padraigTeal.opacity(0.8) : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Modern Create Config View
struct ModernCreateConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var configName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text("New Sniper Config")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Invisible button for balance
                Button("") { }
                    .disabled(true)
                    .opacity(0)
            }
            .padding()
            .background(PadraigTheme.secondaryBackground)
            
            Divider()
            
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "target")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Create Sniper Configuration")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configuration Name")
                        .font(.headline)
                    
                    TextField("Enter config name", text: $configName)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button("Create Configuration") {
                    createConfig()
                }
                .buttonStyle(.borderedProminent)
                .disabled(configName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .controlSize(.large)
                
                Spacer()
            }
            .padding(24)
        }
        .frame(width: 400, height: 350)
    }
    
    private func createConfig() {
        let trimmedName = configName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newConfig = SniperConfig(name: trimmedName)
        modelContext.insert(newConfig)
        try? modelContext.save()
        
        dismiss()
    }
}

// MARK: - Modern Sniper Config Detail
struct ModernSniperConfigDetail: View {
    @Bindable var config: SniperConfig
    @ObservedObject var walletManager: WalletManager
    @ObservedObject var sniperEngine: SniperEngine
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    TextField("Config Name", text: $config.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(PadraigTheme.primaryText)
                        .textFieldStyle(.plain)
                    
                    Spacer()
                    
                    Toggle("Enabled", isOn: $config.enabled)
                        .toggleStyle(.switch)
                }
                
                // Settings sections
                VStack(spacing: 20) {
                    ModernConfigSection(title: "Filter Criteria") {
                        ModernKeywordEditor(keywords: $config.keywords, title: "Keywords")
                        ModernKeywordEditor(keywords: $config.blacklist, title: "Blacklist")
                        ModernKeywordEditor(keywords: $config.twitterAccounts, title: "Twitter Accounts")
                        
                        HStack(spacing: 16) {
                            ModernNumberField(title: "Min Liquidity (SOL)", value: $config.minLiquidity)
                            ModernNumberField(title: "Max Supply", value: $config.maxSupply)
                        }
                    }
                    
                    ModernConfigSection(title: "Trading Settings") {
                        HStack(spacing: 16) {
                            ModernNumberField(title: "Buy Amount (SOL)", value: $config.buyAmount)
                            ModernNumberField(title: "Slippage (%)", value: $config.slippage)
                        }
                        
                        HStack(spacing: 16) {
                            ModernNumberField(title: "Max Gas (SOL)", value: $config.maxGas)
                            ModernIntField(title: "Stagger Delay (ms)", value: $config.staggerDelay)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Trading Pool")
                                .font(.headline)
                                .foregroundColor(PadraigTheme.primaryText)
                            Picker("Pool", selection: $config.tradingPool) {
                                Text("Pump.fun").tag("pump")
                                Text("Bonk.fun").tag("bonk")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    
                    ModernConfigSection(title: "Wallet Selection") {
                        ModernWalletSelector(
                            selectedWallets: $config.selectedWallets,
                            walletManager: walletManager
                        )
                    }
                    
                    ModernConfigSection(title: "Safety Settings") {
                        HStack(spacing: 16) {
                            ModernNumberField(title: "Max Daily Spend (SOL)", value: $config.maxDailySpend)
                            ModernIntField(title: "Cooldown Period (s)", value: $config.cooldownPeriod)
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

// MARK: - Modern Config Section
struct ModernConfigSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
        }
    }
}

// MARK: - Modern Number Field
struct ModernNumberField: View {
    let title: String
    @Binding var value: Double
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .foregroundColor(PadraigTheme.primaryText)
            TextField("0", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Modern Int Field
struct ModernIntField: View {
    let title: String
    @Binding var value: Int
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .foregroundColor(PadraigTheme.primaryText)
            TextField("0", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Modern Keyword Editor
struct ModernKeywordEditor: View {
    @Binding var keywords: [String]
    let title: String
    @State private var newKeyword = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(PadraigTheme.primaryText)
            
            // Add keyword
            HStack {
                TextField("Add \(title.lowercased())", text: $newKeyword)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addKeyword() }
                
                Button("Add") { addKeyword() }
                    .buttonStyle(.bordered)
                    .disabled(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            // Keywords list
            if !keywords.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                    ForEach(keywords, id: \.self) { keyword in
                        HStack {
                            Text(keyword)
                                .font(.caption)
                                .foregroundColor(PadraigTheme.primaryText)
                            
                            Button(action: { removeKeyword(keyword) }) {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                                    .foregroundColor(PadraigTheme.primaryText)
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
    
    private func removeKeyword(_ keyword: String) {
        keywords.removeAll { $0 == keyword }
    }
}

// MARK: - Modern Wallet Selector
struct ModernWalletSelector: View {
    @Binding var selectedWallets: [UUID]
    @ObservedObject var walletManager: WalletManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Select Wallets for Trading")
                    .font(.headline)
                    .foregroundColor(PadraigTheme.primaryText)
                
                Spacer()
                
                Text("\(selectedWallets.count) of \(walletManager.wallets.count) selected")
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
            
            if walletManager.wallets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wallet.pass")
                        .font(.title)
                        .foregroundColor(PadraigTheme.secondaryText)
                    
                    Text("No wallets available")
                        .font(.headline)
                        .foregroundColor(PadraigTheme.primaryText)
                    
                    Text("Create wallets first to use them for sniping")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    // Select All / None buttons
                    HStack {
                        Button(action: selectAllWallets) {
                            Label("Select All", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(.padraigTeal)
                        
                        Button(action: clearAllWallets) {
                            Label("Clear All", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(.padraigRed)
                        
                        Spacer()
                        
                        Button(action: selectActiveWallets) {
                            Label("Active Only", systemImage: "circle.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.padraigOrange)
                    }
                    
                    // Wallet list with checkboxes
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(walletManager.wallets) { wallet in
                            WalletSelectionCard(
                                wallet: wallet,
                                isSelected: selectedWallets.contains(wallet.id),
                                walletManager: walletManager
                            ) {
                                toggleWalletSelection(wallet)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func toggleWalletSelection(_ wallet: Wallet) {
        if selectedWallets.contains(wallet.id) {
            selectedWallets.removeAll { $0 == wallet.id }
        } else {
            selectedWallets.append(wallet.id)
        }
    }
    
    private func selectAllWallets() {
        selectedWallets = walletManager.wallets.map { $0.id }
    }
    
    private func clearAllWallets() {
        selectedWallets.removeAll()
    }
    
    private func selectActiveWallets() {
        selectedWallets = walletManager.wallets.filter { $0.isActive }.map { $0.id }
    }
}

// MARK: - Wallet Selection Card
struct WalletSelectionCard: View {
    let wallet: Wallet
    let isSelected: Bool
    @ObservedObject var walletManager: WalletManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .padraigTeal : PadraigTheme.secondaryText)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(wallet.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(PadraigTheme.primaryText)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Status indicator
                        Circle()
                            .fill(wallet.isActive ? Color.padraigTeal : PadraigTheme.secondaryText)
                            .frame(width: 6, height: 6)
                    }
                    
                    Text("\(wallet.balance.formatted(.number.precision(.fractionLength(3)))) SOL")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                    
                    Text(wallet.publicKey.prefix(8) + "..." + wallet.publicKey.suffix(6))
                        .font(.caption2)
                        .foregroundColor(PadraigTheme.secondaryText.opacity(0.7))
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.padraigTeal.opacity(0.1) : PadraigTheme.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.padraigTeal : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modern Analytics View
struct ModernAnalyticsView: View {
    @ObservedObject var walletManager: WalletManager
    @ObservedObject var sniperEngine: SniperEngine
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Clean Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HStack(spacing: 12) {
                            Image("PadraigLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                            
                            Text("Analytics")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(PadraigTheme.primaryText)
                        }
                        
                        Spacer()
                        
                        // Status indicator
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.padraigTeal)
                                .frame(width: 8, height: 8)
                            Text("Live")
                                .font(.caption)
                                .foregroundColor(PadraigTheme.secondaryText)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(PadraigTheme.secondaryBackground)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    
                    Text("Portfolio insights and trading performance")
                        .font(.subheadline)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                .padding(.horizontal, 20)
                
                // Stats Overview
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    CleanMetricCard(
                        title: "Portfolio",
                        value: "\(totalBalance.formatted(.number.precision(.fractionLength(2))))",
                        unit: "SOL",
                        color: .padraigRed
                    )
                    
                    CleanMetricCard(
                        title: "Wallets",
                        value: "\(activeWalletCount)",
                        unit: "active",
                        color: .padraigTeal
                    )
                    
                    if let stats = sniperEngine.stats {
                        CleanMetricCard(
                            title: "Success",
                            value: "\(stats.successRate.formatted(.number.precision(.fractionLength(0))))",
                            unit: "%",
                            color: .padraigOrange
                        )
                        
                        CleanMetricCard(
                            title: "Speed",
                            value: "\(stats.averageSpeed.formatted(.number.precision(.fractionLength(0))))",
                            unit: "ms",
                            color: .padraigTeal
                        )
                    } else {
                        CleanMetricCard(title: "Success", value: "--", unit: "%", color: .padraigOrange)
                        CleanMetricCard(title: "Speed", value: "--", unit: "ms", color: .padraigTeal)
                    }
                }
                .padding(.horizontal, 20)
                
                // Details Section
                HStack(alignment: .top, spacing: 20) {
                    // Wallets
                    CleanSectionCard(title: "Wallets", icon: "wallet.pass") {
                        CleanWalletsList(walletManager: walletManager)
                    }
                    
                    // Activity
                    CleanSectionCard(title: "Activity", icon: "chart.line.uptrend.xyaxis") {
                        CleanActivityList(sniperEngine: sniperEngine)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
        }
        .background(
            LinearGradient(
                colors: [
                    PadraigTheme.primaryBackground,
                    Color.padraigTeal.opacity(0.05),
                    Color.padraigOrange.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private var totalBalance: Double {
        walletManager.balances.values.reduce(0, +)
    }
    
    private var activeWalletCount: Int {
        walletManager.wallets.filter { $0.isActive }.count
    }
}

// MARK: - Clean Metric Card
struct CleanMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Spacer()
            }
            
            VStack(spacing: 4) {
                HStack {
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(PadraigTheme.primaryText)
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                        .padding(.leading, 2)
                    Spacer()
                }
                
                HStack {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Clean Section Card
struct CleanSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(PadraigTheme.secondaryText)
                    .font(.title3)
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(PadraigTheme.primaryText)
                Spacer()
            }
            
            content
        }
        .padding(20)
        .background(PadraigTheme.secondaryBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Clean Wallets List
struct CleanWalletsList: View {
    @ObservedObject var walletManager: WalletManager
    
    var body: some View {
        VStack(spacing: 12) {
            if walletManager.wallets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "wallet.pass")
                        .font(.title2)
                        .foregroundColor(PadraigTheme.secondaryText)
                    Text("No wallets")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                .frame(height: 60)
            } else {
                ForEach(walletManager.wallets.prefix(3)) { wallet in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(wallet.isActive ? Color.padraigTeal : PadraigTheme.secondaryText)
                            .frame(width: 6, height: 6)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(wallet.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(PadraigTheme.primaryText)
                            Text("\(wallet.balance.formatted(.number.precision(.fractionLength(2)))) SOL")
                                .font(.caption2)
                                .foregroundColor(PadraigTheme.secondaryText)
                        }
                        
                        Spacer()
                    }
                }
                
                if walletManager.wallets.count > 3 {
                    Text("+\(walletManager.wallets.count - 3) more")
                        .font(.caption2)
                        .foregroundColor(PadraigTheme.secondaryText)
                        .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Clean Activity List
struct CleanActivityList: View {
    @ObservedObject var sniperEngine: SniperEngine
    
    var body: some View {
        VStack(spacing: 12) {
            if sniperEngine.recentMatches.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.title2)
                        .foregroundColor(PadraigTheme.secondaryText)
                    Text("No recent activity")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                .frame(height: 60)
            } else {
                ForEach(sniperEngine.recentMatches.prefix(3)) { match in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.padraigOrange)
                            .frame(width: 6, height: 6)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(match.token.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(PadraigTheme.primaryText)
                                .lineLimit(1)
                            Text("Score: \(match.score.formatted(.number.precision(.fractionLength(0))))")
                                .font(.caption2)
                                .foregroundColor(PadraigTheme.secondaryText)
                        }
                        
                        Spacer()
                        
                        Text(match.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundColor(PadraigTheme.secondaryText)
                    }
                }
                
                if sniperEngine.recentMatches.count > 3 {
                    Text("+\(sniperEngine.recentMatches.count - 3) more")
                        .font(.caption2)
                        .foregroundColor(PadraigTheme.secondaryText)
                        .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Quick Stat Pill (Legacy - keeping for compatibility)
struct QuickStatPill: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(title)
                .font(.caption2)
                .foregroundColor(PadraigTheme.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(color.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

// MARK: - Analytics Metric Card
struct AnalyticsMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let trend: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
                
                Text(trend)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(trend.hasPrefix("+") ? .padraigTeal : trend.hasPrefix("-") ? .padraigRed : PadraigTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(PadraigTheme.secondaryBackground)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PadraigTheme.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Analytics Wallet Breakdown
struct AnalyticsWalletBreakdown: View {
    @ObservedObject var walletManager: WalletManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if walletManager.wallets.isEmpty {
                Text("No wallets created")
                    .font(.caption)
                    .foregroundColor(PadraigTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ForEach(walletManager.wallets.prefix(6)) { wallet in
                    HStack(spacing: 12) {
                        // Status indicator
                        Circle()
                            .fill(wallet.isActive ? Color.padraigTeal : PadraigTheme.secondaryText)
                            .frame(width: 10, height: 10)
                        
                        // Wallet info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(wallet.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            Text("\(wallet.publicKey.prefix(8))...")
                                .font(.caption2)
                                .foregroundColor(PadraigTheme.secondaryText)
                        }
                        
                        Spacer()
                        
                        // Balance and percentage
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(wallet.balance.formatted(.number.precision(.fractionLength(3)))) SOL")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            Text("\(walletPercentage(wallet).formatted(.number.precision(.fractionLength(1))))%")
                                .font(.caption2)
                                .foregroundColor(PadraigTheme.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                if walletManager.wallets.count > 6 {
                    Text("... and \(walletManager.wallets.count - 6) more wallets")
                        .font(.caption2)
                        .foregroundColor(PadraigTheme.secondaryText)
                        .padding(.top, 8)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PadraigTheme.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func walletPercentage(_ wallet: Wallet) -> Double {
        let total = walletManager.balances.values.reduce(0, +)
        guard total > 0 else { return 0 }
        return (wallet.balance / total) * 100
    }
}

// MARK: - Analytics Recent Activity
struct AnalyticsRecentActivity: View {
    @ObservedObject var sniperEngine: SniperEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if sniperEngine.recentMatches.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.title2)
                        .foregroundColor(PadraigTheme.secondaryText)
                    Text("No recent activity")
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ForEach(sniperEngine.recentMatches.prefix(6)) { match in
                    HStack(spacing: 12) {
                        // Token indicator
                        Circle()
                            .fill(Color.orange.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                            )
                        
                        // Match info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(match.token.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(match.matchReasons.prefix(2).joined(separator: ", "))
                                .font(.caption2)
                                .foregroundColor(PadraigTheme.secondaryText)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Score and time
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Score: \(match.score.formatted(.number.precision(.fractionLength(0))))")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            Text(match.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundColor(PadraigTheme.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PadraigTheme.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
    }
}