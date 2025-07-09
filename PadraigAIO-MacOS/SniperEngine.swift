//
//  SniperEngine.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/24/25.
//

import Foundation
import Combine
import SwiftData

// MARK: - Sniper Engine
class SniperEngine: ObservableObject {
    @Published var isActive = false
    @Published var activeSnipers: [SniperConfig] = []
    @Published var recentMatches: [TokenMatch] = []
    @Published var stats: SniperStats?
    @Published var todaySnipeCount = 0
    @Published var lastError: String?
    
    var modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    private var walletManager: WalletManager?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        loadSniperConfigs()
        loadStats()
        
        // Listen for new tokens from WebSocket (basic tokens)
        NotificationCenter.default.publisher(for: NSNotification.Name("NewTokenCreated"))
            .compactMap { (notification: Notification) -> TokenCreation? in
                print("📨 SniperEngine received NewTokenCreated notification")
                guard let token = notification.object as? TokenCreation else {
                    print("❌ Failed to cast notification object to TokenCreation")
                    return nil
                }
                print("📨 Successfully parsed token: \(token.name) (\(token.symbol))")
                return token
            }
            .sink { [weak self] (token: TokenCreation) in
                print("🎯 SniperEngine about to process basic token: \(token.name)")
                self?.processNewToken(token, enhancedMetadata: nil)
            }
            .store(in: &cancellables)
        
        // Listen for enhanced tokens (with IPFS metadata)
        NotificationCenter.default.publisher(for: NSNotification.Name("EnhancedTokenCreated"))
            .compactMap { (notification: Notification) -> EnhancedTokenForSniper? in
                print("📨 SniperEngine received EnhancedTokenCreated notification")
                guard let enhancedToken = notification.object as? EnhancedTokenForSniper else {
                    print("❌ Failed to cast notification object to EnhancedTokenForSniper")
                    return nil
                }
                print("📨 Successfully parsed enhanced token: \(enhancedToken.token.name) (\(enhancedToken.token.symbol))")
                return enhancedToken
            }
            .sink { [weak self] (enhancedToken: EnhancedTokenForSniper) in
                print("🎯 SniperEngine about to process enhanced token: \(enhancedToken.token.name)")
                self?.processNewToken(enhancedToken.token, enhancedMetadata: enhancedToken.enhancedMetadata)
            }
            .store(in: &cancellables)
        
        // Reset daily stats at midnight
        Timer.publish(every: 3600, on: .main, in: .common) // Check every hour
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkDailyReset()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Configuration Management
    func loadSniperConfigs() {
        let request = FetchDescriptor<SniperConfig>()
        do {
            let allConfigs = try modelContext.fetch(request)
            activeSnipers = allConfigs.filter { $0.enabled }
            print("🔧 Loaded \(allConfigs.count) total sniper configs, \(activeSnipers.count) active")
            for config in allConfigs {
                print("   Config: \(config.name) - enabled: \(config.enabled)")
                print("     Symbol keywords: \(config.symbolKeywords)")
                print("     Description keywords: \(config.descriptionKeywords)")
                print("     Twitter accounts: \(config.twitterAccounts)")
            }
        } catch {
            print("❌ Failed to load sniper configs: \(error)")
        }
    }
    
    func addSniperConfig(_ config: SniperConfig) {
        print("➕ Adding new sniper config: \(config.name)")
        print("   Symbol keywords: \(config.symbolKeywords)")
        print("   Description keywords: \(config.descriptionKeywords)")
        print("   Twitter accounts: \(config.twitterAccounts)")
        print("   Enabled: \(config.enabled)")
        modelContext.insert(config)
        try? modelContext.save()
        loadSniperConfigs()
    }
    
    func updateSniperConfig(_ config: SniperConfig) {
        config.lastUpdated = Date()
        try? modelContext.save()
        loadSniperConfigs()
    }
    
    func deleteSniperConfig(_ config: SniperConfig) {
        modelContext.delete(config)
        try? modelContext.save()
        loadSniperConfigs()
    }
    
    // MARK: - Token Processing
    func processNewToken(_ token: TokenCreation, enhancedMetadata: EnhancedTokenInfo? = nil) {
        print("🎯 Sniper processing new token: \(token.name) (\(token.symbol))")
        print("   Token description: '\(token.description ?? "None")'")
        
        guard !activeSnipers.isEmpty else {
            print("⚠️ No active sniper configurations found")
            return
        }
        
        print("📋 Found \(activeSnipers.count) sniper configurations:")
        for config in activeSnipers {
            print("   - \(config.name): enabled=\(config.enabled)")
            print("     Symbol keywords: \(config.symbolKeywords)")
            print("     Description keywords: \(config.descriptionKeywords)")
            print("     Twitter accounts: \(config.twitterAccounts)")
        }
        
        for config in activeSnipers where config.enabled {
            print("🔍 Evaluating token against config: \(config.name)")
            if let match = evaluateToken(token, against: config, enhancedMetadata: enhancedMetadata) {
                print("🎯 ✅ Token \(token.symbol) matches sniper config: \(config.name)")
                print("   Match score: \(match.score)")
                print("   Match reasons: \(match.matchReasons)")
                
                // Add to recent matches on main thread
                DispatchQueue.main.async {
                    self.recentMatches.append(match)
                    if self.recentMatches.count > 50 {
                        self.recentMatches.removeFirst(self.recentMatches.count - 50)
                    }
                }
                
                // Execute snipe if auto-execution is enabled
                if !config.requireConfirmation {
                    print("🚀 Auto-executing snipe for \(token.symbol)")
                    Task {
                        await executeSnipe(for: match)
                    }
                } else {
                    print("⏸️ Snipe requires manual confirmation for \(token.symbol)")
                    // Post notification for manual approval
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TokenMatchRequiresApproval"),
                        object: match
                    )
                }
            } else {
                print("❌ Token \(token.symbol) does not match config: \(config.name)")
            }
        }
    }
    
    private func evaluateToken(_ token: TokenCreation, against config: SniperConfig, enhancedMetadata: EnhancedTokenInfo? = nil) -> TokenMatch? {
        var score: Double = 0
        var reasons: [String] = []
        
        print("🔍 === EVALUATING TOKEN: \(token.symbol) ===")
        print("   Config: \(config.name)")
        print("   Starting score: \(score)")
        
        // Check symbol keywords
        var symbolMatches: [String] = []
        var descriptionMatches: [String] = []
        
        if !config.symbolKeywords.isEmpty {
            let tokenSymbolText = "\(token.name) \(token.symbol)".lowercased()
            print("🔍 Checking token symbol/name '\(tokenSymbolText)' against symbol keywords: \(config.symbolKeywords)")
            
            // Filter out very short keywords that might cause false matches
            let validSymbolKeywords = config.symbolKeywords.filter { $0.count >= 2 }
            symbolMatches = validSymbolKeywords.filter { keyword in
                tokenSymbolText.contains(keyword.lowercased())
            }
            
            if !symbolMatches.isEmpty {
                print("✅ Symbol keyword matches for \(token.symbol): \(symbolMatches)")
                score += Double(symbolMatches.count) * 15 // Higher score for symbol matches
                reasons.append("Symbol Keywords: \(symbolMatches.joined(separator: ", "))")
            } else {
                print("⚪ No symbol keyword matches for \(token.symbol)")
            }
        }
        
        // Check description keywords
        if !config.descriptionKeywords.isEmpty {
            let tokenDescriptionText = (token.description ?? "").lowercased()
            print("🔍 Checking token description '\(tokenDescriptionText)' against description keywords: \(config.descriptionKeywords)")
            
            // Filter out very short keywords that might cause false matches
            let validDescriptionKeywords = config.descriptionKeywords.filter { $0.count >= 2 }
            descriptionMatches = validDescriptionKeywords.filter { keyword in
                tokenDescriptionText.contains(keyword.lowercased())
            }
            
            if !descriptionMatches.isEmpty {
                print("✅ Description keyword matches for \(token.symbol): \(descriptionMatches)")
                score += Double(descriptionMatches.count) * 10 // Standard score for description matches
                reasons.append("Description Keywords: \(descriptionMatches.joined(separator: ", "))")
            } else {
                print("⚪ No description keyword matches for \(token.symbol)")
            }
        }
        
        // Require at least one keyword match if any keywords are configured
        if !config.symbolKeywords.isEmpty || !config.descriptionKeywords.isEmpty {
            if symbolMatches.isEmpty && descriptionMatches.isEmpty {
                print("❌ No keyword matches found for \(token.symbol) in either symbol or description")
                return nil // Must match at least one keyword
            }
        }
        
        print("   Score after keywords: \(score)")
        
        // Check blacklist
        if !config.blacklist.isEmpty {
            let tokenText = "\(token.name) \(token.symbol) \(token.description ?? "")".lowercased()
            let blacklistedTerms = config.blacklist.filter { term in
                tokenText.contains(term.lowercased())
            }
            
            if !blacklistedTerms.isEmpty {
                print("❌ Token \(token.symbol) rejected: blacklisted terms found: \(blacklistedTerms)")
                return nil // Reject if any blacklisted terms found
            }
            print("   ✅ Blacklist check passed")
        }
        
        // Check creator address
        if let targetCreator = config.creatorAddress, !targetCreator.isEmpty {
            if token.creator != targetCreator {
                print("❌ Token \(token.symbol) rejected: creator mismatch. Expected: \(targetCreator), Got: \(token.creator ?? "nil")")
                return nil // Must match specific creator
            }
            score += 20
            reasons.append("Creator match")
            print("   ✅ Creator check passed, score: \(score)")
        } else {
            print("   ⚪ No creator requirement")
        }
        
        // Check Twitter accounts in metadata
        if !config.twitterAccounts.isEmpty {
            print("   🐦 Checking for Twitter account matches...")
            let twitterMatches = checkTwitterAccountMatches(token: token, targetAccounts: config.twitterAccounts, enhancedMetadata: enhancedMetadata)
            
            if !twitterMatches.isEmpty {
                score += 25 // High score for Twitter matches
                reasons.append("Twitter: \(twitterMatches.joined(separator: ", "))")
                print("   ✅ Twitter account matches found: \(twitterMatches), score: \(score)")
            } else {
                // If Twitter accounts are specified but no matches found, reject the token
                print("❌ Token \(token.symbol) rejected: no Twitter account matches (required: \(config.twitterAccounts))")
                return nil
            }
        } else {
            print("   ⚪ No Twitter account requirements")
        }
        
        // Check liquidity (if available)
        if let liquidity = token.initialLiquidity {
            print("   Token liquidity: \(liquidity), required: \(config.minLiquidity)")
            if liquidity < config.minLiquidity {
                print("❌ Token \(token.symbol) rejected: liquidity too low (\(liquidity) < \(config.minLiquidity))")
                return nil // Below minimum liquidity
            }
            score += 5
            reasons.append("Liquidity: \(String(format: "%.2f", liquidity)) SOL")
            print("   ✅ Liquidity check passed, score: \(score)")
        } else {
            print("   ⚪ No liquidity data available")
        }
        
        // Check supply (if available)
        if let supply = token.totalSupply {
            print("   Token supply: \(supply), max allowed: \(config.maxSupply)")
            if supply > config.maxSupply {
                print("❌ Token \(token.symbol) rejected: supply too high (\(supply) > \(config.maxSupply))")
                return nil // Above maximum supply
            }
            score += 5
            reasons.append("Supply: \(String(format: "%.0f", supply))")
            print("   ✅ Supply check passed, score: \(score)")
        } else {
            print("   ⚪ No supply data available")
        }
        
        // Check daily spending limit
        let dailySpent = stats?.dailySpent ?? 0
        print("   Daily spent: \(dailySpent), limit: \(config.maxDailySpend)")
        if dailySpent >= config.maxDailySpend {
            print("❌ Token \(token.symbol) rejected: daily spending limit reached (\(dailySpent) >= \(config.maxDailySpend))")
            return nil // Daily limit reached
        }
        print("   ✅ Daily limit check passed")
        
        // Check cooldown period
        if let lastSnipe = stats?.lastSnipeTime {
            let timeSinceLastSnipe = Date().timeIntervalSince(lastSnipe)
            print("   Time since last snipe: \(timeSinceLastSnipe)s, cooldown: \(config.cooldownPeriod)s")
            if timeSinceLastSnipe < Double(config.cooldownPeriod) {
                print("❌ Token \(token.symbol) rejected: still in cooldown (\(timeSinceLastSnipe) < \(config.cooldownPeriod))")
                return nil // Still in cooldown
            }
            print("   ✅ Cooldown check passed")
        } else {
            print("   ⚪ No previous snipe recorded")
        }
        
        // Create match if score is above threshold
        print("   Final score: \(score), threshold: 10")
        if score > 10 { // Minimum score threshold
            print("✅ Token \(token.symbol) ACCEPTED with score \(score)")
            return TokenMatch(
                token: token,
                config: config,
                score: score,
                matchReasons: reasons,
                timestamp: Date()
            )
        }
        
        print("❌ Token \(token.symbol) rejected: score too low (\(score) <= 10)")
        return nil
    }
    
    // MARK: - Twitter Account Checking
    private func checkTwitterAccountMatches(token: TokenCreation, targetAccounts: [String], enhancedMetadata: EnhancedTokenInfo? = nil) -> [String] {
        var matches: [String] = []
        
        print("🔍 Checking token for Twitter account matches...")
        print("   Target accounts: \(targetAccounts)")
        
        // Get all social links from the token
        var allSocialLinks: [String] = []
        
        // Add WebSocket social links if available
        if let webSocketLinks = token.webSocketSocialLinks {
            allSocialLinks.append(contentsOf: webSocketLinks)
            print("   WebSocket social links: \(webSocketLinks)")
        }
        
        // Add IPFS social links from enhanced metadata if available
        if let enhancedLinks = enhancedMetadata?.socialLinks {
            allSocialLinks.append(contentsOf: enhancedLinks)
            print("   IPFS social links: \(enhancedLinks)")
        }
        
        print("   All social links to check: \(allSocialLinks)")
        
        // Check each target account against the token's social links
        for targetAccount in targetAccounts {
            let normalizedTarget = normalizeTwitterAccount(targetAccount)
            print("   Checking target account: \(targetAccount) (normalized: \(normalizedTarget))")
            
            for socialLink in allSocialLinks {
                if isTwitterAccountMatch(socialLink: socialLink, targetAccount: normalizedTarget) {
                    matches.append(targetAccount)
                    print("   ✅ Found match: \(socialLink) matches \(targetAccount)")
                    break // Found a match for this target account
                }
            }
        }
        
        print("🐦 Twitter account check complete. Matches: \(matches)")
        return matches
    }
    
    private func normalizeTwitterAccount(_ account: String) -> String {
        // Remove common prefixes and clean up the account name
        var normalized = account.lowercased()
        
        // Remove URL prefixes
        normalized = normalized.replacingOccurrences(of: "https://twitter.com/", with: "")
        normalized = normalized.replacingOccurrences(of: "https://x.com/", with: "")
        normalized = normalized.replacingOccurrences(of: "twitter.com/", with: "")
        normalized = normalized.replacingOccurrences(of: "x.com/", with: "")
        normalized = normalized.replacingOccurrences(of: "@", with: "")
        
        // Remove trailing slash and query parameters
        if let slashIndex = normalized.firstIndex(of: "/") {
            normalized = String(normalized[..<slashIndex])
        }
        if let questionIndex = normalized.firstIndex(of: "?") {
            normalized = String(normalized[..<questionIndex])
        }
        
        return normalized.trimmingCharacters(in: .whitespaces)
    }
    
    private func isTwitterAccountMatch(socialLink: String, targetAccount: String) -> Bool {
        let normalizedSocialLink = normalizeTwitterAccount(socialLink)
        
        // Check if it's a Twitter/X URL and contains the target account
        let isTwitterUrl = socialLink.lowercased().contains("twitter.com") || 
                          socialLink.lowercased().contains("x.com")
        
        if isTwitterUrl {
            return normalizedSocialLink.contains(targetAccount) || targetAccount.contains(normalizedSocialLink)
        }
        
        return false
    }
    
    // MARK: - Snipe Execution
    @MainActor
    func executeSnipe(for match: TokenMatch) async {
        guard let walletManager = walletManager else {
            lastError = "Wallet manager not available"
            print("❌ Snipe failed: Wallet manager not available")
            return
        }
        
        let config = match.config
        let token = match.token
        
        print("💰 Executing snipe for \(token.symbol) with config \(config.name)")
        print("   Buy amount: \(config.buyAmount) SOL")
        print("   Slippage: \(config.slippage)%")
        
        // Update stats
        updateStats { stats in
            stats.totalAttempts += 1
        }
        
        // Get selected wallets
        let selectedWallets = walletManager.wallets.filter { wallet in
            config.selectedWallets.contains(wallet.id) && wallet.isActive
        }
        
        if selectedWallets.isEmpty {
            lastError = "No active wallets selected for config \(config.name)"
            updateStats { stats in
                stats.failedSnipes += 1
            }
            return
        }
        
        // Execute trades on selected wallets with stagger delay
        for (index, wallet) in selectedWallets.enumerated() {
            // Add stagger delay between wallets
            if index > 0 {
                try? await Task.sleep(nanoseconds: UInt64(config.staggerDelay) * 1_000_000) // Convert ms to ns
            }
            
            await executeSingleSnipe(wallet: wallet, token: token, config: config)
        }
    }
    
    private func executeSingleSnipe(wallet: Wallet, token: TokenCreation, config: SniperConfig) async {
        let startTime = Date()
        
        // Create transaction record
        let transaction = TransactionRecord(
            tokenMint: token.mint,
            tokenName: token.name,
            tokenSymbol: token.symbol,
            transactionType: "buy",
            amount: config.buyAmount,
            price: 0.0, // Will be updated after execution
            slippage: config.slippage,
            gasUsed: 0.0,
            walletUsed: wallet.publicKey
        )
        
        do {
            // Execute the buy transaction
            let result = await executeBuyTransaction(
                wallet: wallet,
                tokenMint: token.mint,
                amount: config.buyAmount,
                slippage: config.slippage,
                pool: config.tradingPool
            )
            
            let executionTime = Date().timeIntervalSince(startTime) * 1000 // Convert to ms
            
            if result.success {
                transaction.success = true
                transaction.txSignature = result.signature
                transaction.gasUsed = result.gasUsed ?? 0.0
                transaction.price = result.price ?? 0.0
                
                await MainActor.run {
                    updateStats { stats in
                        stats.successfulSnipes += 1
                        stats.totalSpent += config.buyAmount
                        stats.dailySpent += config.buyAmount
                        stats.lastSnipeTime = Date()
                        
                        // Update average speed
                        let totalTime = stats.averageSpeed * Double(stats.successfulSnipes - 1) + executionTime
                        stats.averageSpeed = totalTime / Double(stats.successfulSnipes)
                    }
                    
                    todaySnipeCount += 1
                }
                
                print("✅ Successful snipe: \(token.symbol) in \(String(format: "%.0f", executionTime))ms")
                
            } else {
                transaction.success = false
                transaction.errorMessage = result.error
                
                await MainActor.run {
                    updateStats { stats in
                        stats.failedSnipes += 1
                    }
                }
                
                print("❌ Failed snipe: \(token.symbol) - \(result.error ?? "Unknown error")")
            }
            
            // Save transaction record
            modelContext.insert(transaction)
            try? modelContext.save()
            
        } catch {
            transaction.success = false
            transaction.errorMessage = error.localizedDescription
            
            await MainActor.run {
                updateStats { stats in
                    stats.failedSnipes += 1
                }
                lastError = error.localizedDescription
            }
            
            modelContext.insert(transaction)
            try? modelContext.save()
        }
    }
    
    private func executeBuyTransaction(wallet: Wallet, tokenMint: String, amount: Double, slippage: Double, pool: String) async -> BuyTransactionResult {
        guard let walletManager = walletManager else {
            return BuyTransactionResult(
                success: false,
                signature: nil,
                price: nil,
                gasUsed: 0.001,
                error: "Wallet manager not available"
            )
        }
        
        let result = await walletManager.buyToken(
            mint: tokenMint,
            amount: amount,
            slippage: slippage,
            wallet: wallet,
            pool: pool
        )
        
        return BuyTransactionResult(
            success: result.success,
            signature: result.signature,
            price: result.price,
            gasUsed: result.gasUsed,
            error: result.error
        )
    }
    
    // MARK: - Statistics Management
    private func loadStats() {
        let request = FetchDescriptor<SniperStats>()
        do {
            let allStats = try modelContext.fetch(request)
            if let existingStats = allStats.first {
                stats = existingStats
            } else {
                // Create new stats with some demo data
                let newStats = SniperStats()
                newStats.totalAttempts = 47
                newStats.successfulSnipes = 42
                newStats.failedSnipes = 5
                newStats.totalSpent = 12.45
                newStats.totalProfit = 3.21
                newStats.averageSpeed = 234.5
                newStats.dailySpent = 2.1
                modelContext.insert(newStats)
                try? modelContext.save()
                stats = newStats
            }
        } catch {
            print("Failed to load stats: \(error)")
            stats = SniperStats()
        }
        
        // Update today's count
        updateTodayCount()
    }
    
    private func updateStats(_ update: (SniperStats) -> Void) {
        guard let stats = stats else { return }
        update(stats)
        try? modelContext.save()
    }
    
    private func checkDailyReset() {
        guard let stats = stats else { return }
        
        let calendar = Calendar.current
        if !calendar.isDate(stats.lastResetDate, inSameDayAs: Date()) {
            // Reset daily counters
            stats.dailySpent = 0.0
            stats.lastResetDate = Date()
            try? modelContext.save()
            
            updateTodayCount()
        }
    }
    
    private func updateTodayCount() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let request = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate<TransactionRecord> { transaction in
                transaction.timestamp >= today && transaction.timestamp < tomorrow && transaction.success
            }
        )
        
        do {
            let todayTransactions = try modelContext.fetch(request)
            todaySnipeCount = todayTransactions.count
        } catch {
            print("Failed to count today's transactions: \(error)")
        }
    }
    
    // MARK: - Public Interface
    func setWalletManager(_ walletManager: WalletManager) {
        print("🔗 SniperEngine received WalletManager reference")
        self.walletManager = walletManager
    }
    
    func toggleSniper(active: Bool) {
        isActive = active
        if active {
            loadSniperConfigs()
        }
    }
    
    func approveMatch(_ match: TokenMatch) {
        Task {
            await executeSnipe(for: match)
        }
    }
    
    func rejectMatch(_ match: TokenMatch) {
        // Remove from recent matches
        recentMatches.removeAll { $0.id == match.id }
    }
    
    // MARK: - Debug Methods
    func debugSniperStatus() {
        print("🔍 === SNIPER DEBUG STATUS ===")
        print("   Wallet Manager: \(walletManager != nil ? "✅ Connected" : "❌ Missing")")
        print("   Active: \(isActive)")
        print("   Configurations: \(activeSnipers.count)")
        for config in activeSnipers {
            print("     - \(config.name): enabled=\(config.enabled)")
            print("       Symbol keywords: \(config.symbolKeywords)")
            print("       Description keywords: \(config.descriptionKeywords)")
            print("       Twitter accounts: \(config.twitterAccounts)")
        }
        print("   Recent matches: \(recentMatches.count)")
        print("=================================")
    }
    
    func testTokenProcessing() {
        let testToken = TokenCreation(
            mint: "TEST123",
            name: "Test Coin Token",
            symbol: "COIN",
            description: "A test coin for debugging",
            image: nil,
            createdTimestamp: Date().timeIntervalSince1970 * 1000,
            creator: nil,
            totalSupply: nil,
            initialLiquidity: nil,
            raydiumPool: nil,
            complete: true,
            metadataUri: nil, // No metadata URI for test token
            webSocketSocialLinks: nil, // No WebSocket social links for test token
            // Pump.fun specific fields - nil for test token
            marketCapSol: nil,
            solAmount: nil,
            initialBuy: nil,
            vSolInBondingCurve: nil,
            vTokensInBondingCurve: nil
        )
        
        print("🧪 Testing with mock token containing 'coin'")
        processNewToken(testToken, enhancedMetadata: nil)
    }
}

// MARK: - Supporting Types
struct TokenMatch: Identifiable {
    let id = UUID()
    let token: TokenCreation
    let config: SniperConfig
    let score: Double
    let matchReasons: [String]
    let timestamp: Date
}

struct BuyTransactionResult {
    let success: Bool
    let signature: String?
    let price: Double?
    let gasUsed: Double?
    let error: String?
}