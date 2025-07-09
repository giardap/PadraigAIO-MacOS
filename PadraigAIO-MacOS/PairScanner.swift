//
//  PairScanner.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/24/25.
//

import SwiftUI
import SwiftData
import Foundation
import Combine

// MARK: - Pair Data Models
struct TradingPair: Codable, Identifiable {
    let id: String
    let address: String
    let baseToken: TokenInfo
    let quoteToken: TokenInfo
    let dex: String // "raydium", "orca", "pump.fun", etc.
    let liquidity: Double
    let volume24h: Double
    let priceChange24h: Double
    let marketCap: Double?
    let createdAt: Date
    let migrationStatus: MigrationStatus
    let riskScore: Double // 0-100, higher = riskier
    let holderCount: Int?
    let topHolderPercent: Double? // % held by top holder
    let enhancedMetadata: EnhancedTokenInfo? // Store IPFS metadata
    
    var age: TimeInterval {
        Date().timeIntervalSince(createdAt)
    }
    
    var ageFormatted: String {
        let minutes = Int(age / 60)
        let hours = Int(age / 3600)
        let days = Int(age / 86400)
        
        if days > 0 {
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

struct TokenInfo: Codable {
    let address: String
    let symbol: String
    let name: String
    let decimals: Int
    let logoURI: String?
}

enum MigrationStatus: String, Codable, CaseIterable {
    case preMigration = "pre_migration"
    case migrating = "migrating"
    case migrated = "migrated"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .preMigration: return "Pre-Migration"
        case .migrating: return "Migrating"
        case .migrated: return "Migrated"
        case .failed: return "Failed"
        }
    }
    
    var color: Color {
        switch self {
        case .preMigration: return .padraigOrange
        case .migrating: return .padraigTeal
        case .migrated: return .padraigRed
        case .failed: return Color.gray
        }
    }
}

// MARK: - Pair Scanner Manager
class PairScannerManager: ObservableObject {
    @Published var pairs: [TradingPair] = []
    @Published var pairUpdateBatch: [TradingPair] = [] // Batch updates for performance
    @Published var isScanning = false
    @Published var lastUpdate = Date()
    @Published var selectedDEXs: Set<String> = ["raydium", "orca", "pump.fun"]
    @Published var selectedMigrationStatus: Set<MigrationStatus> = Set(MigrationStatus.allCases)
    @Published var minLiquidity: Double = 10
    @Published var maxAge: Int = 24 // hours
    @Published var isUsingRealAPI = true
    @Published var apiErrorMessage: String?
    @Published var isPaused = false // For hover-to-pause functionality
    @Published var isDialogOpen = false // Track if any dialog is currently open
    @Published var isProcessingIPFS = false // Track if IPFS processing is happening
    
    private var timer: Timer?
    private let apiService = PairScannerAPIService()
    private let webSocketManager = PumpPortalWebSocketManager()
    private let heliusWebSocketManager = HeliusLaserStreamManager()
    private let blockchainMonitor = SolanaBlockchainMonitor(
        apiKey: APIConfiguration.heliusAPIKey, 
        useHelius: APIConfiguration.useHeliusAPI
    )
    private let ipfsService = IPFSService()
    
    init() {
        // Print API setup instructions
        APIConfiguration.printSetupInstructions()
        
        // Setup WebSocket for pump.fun feed
        setupWebSocketObservers()
        
        // Setup blockchain monitor observers
        setupBlockchainMonitorObservers()
        
        // Don't auto-start scanning - let user manually start
        // Load initial real data once
        Task {
            await loadRealPairs()
        }
    }
    
    func startScanning() {
        isScanning = true
        
        // Start DexScreener API scanning with longer interval to avoid repetition
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.scanForNewPairs()
        }
        
        // Start pump.fun WebSocket feed (this provides the real new tokens)
        webSocketManager.startTokenFeed()
        
        // Start blockchain monitoring for comprehensive token detection
        blockchainMonitor.startMonitoring()
        
        // Initial load of real pairs
        Task {
            await loadRealPairs()
            
            // Start IPFS enhancement for initial pairs in background
            await enhancePairsWithIPFS()
        }
        
        // Note: Helius LaserStream requires premium subscription
        // heliusWebSocketManager.startLaserStream()
        
        print("Started unified scanning: DexScreener (30s) + Pump.fun WebSocket + Blockchain Monitor + Initial load")
    }
    
    func stopScanning() {
        isScanning = false
        
        // Stop DexScreener API scanning
        timer?.invalidate()
        timer = nil
        
        // Stop pump.fun WebSocket feed
        webSocketManager.stopTokenFeed()
        
        // Stop blockchain monitoring
        blockchainMonitor.stopMonitoring()
        
        // Note: Helius LaserStream disabled (premium feature)
        // heliusWebSocketManager.stopLaserStream()
        
        print("Stopped unified scanning")
    }
    
    private func scanForNewPairs() {
        Task {
            await scanForRealPairs()
        }
    }
    
    func toggleAPIMode() {
        isUsingRealAPI.toggle()
        apiErrorMessage = nil
        
        if isUsingRealAPI {
            Task {
                await loadRealPairs()
            }
        }
    }
    
    
    /// Force refresh real pairs manually
    func forceRefresh() {
        Task {
            await loadRealPairs()
        }
    }
    
    func retryRealAPI() {
        Task {
            await loadRealPairs()
        }
    }
    
    // MARK: - Hover-to-Pause Functionality
    
    func pauseFeed() {
        isPaused = true
        print("📊 Pair feed paused - isPaused now: \(isPaused)")
        print("   Current scanning state: \(isScanning)")
        print("   Current pairs count: \(pairs.count)")
    }
    
    func resumeFeed() {
        // Only resume if no dialog is open
        guard !isDialogOpen else {
            print("📊 Resume request ignored - dialog is open")
            return
        }
        
        isPaused = false
        print("📊 Pair feed resumed - isPaused now: \(isPaused)")
        print("   Current scanning state: \(isScanning)")
        print("   Current pairs count: \(pairs.count)")
    }
    
    // MARK: - Dialog State Management
    
    func dialogOpened() {
        isDialogOpen = true
        isPaused = true
        print("📱 Dialog opened - feed paused, dialog state: \(isDialogOpen)")
    }
    
    func dialogClosed() {
        isDialogOpen = false
        isPaused = false
        print("📱 Dialog closed - feed resumed, dialog state: \(isDialogOpen)")
    }
    
    // MARK: - IPFS Enhancement
    
    /// Process new token with complete IPFS enhancement before adding to feed (optimized with background threading)
    private func processAndAddNewToken(_ token: TokenCreation) async {
        print("📦 Starting complete token processing for: \(token.symbol) on background thread")
        
        await MainActor.run {
            isProcessingIPFS = true
        }
        
        // Process everything on background thread to avoid blocking UI
        let result = await Task.detached(priority: .userInitiated) {
            // Step 1: Create base trading pair
            let basePair = self.convertTokenToTradingPair(token)
            print("   ✅ Created base pair on background thread")
            
            // Step 2: Enhance with IPFS metadata (this already runs on background thread)
            print("   🌐 Fetching IPFS metadata on background thread...")
            let enhancedInfo = await self.ipfsService.enhanceTokenInfo(basePair.baseToken, metadataUri: token.metadataUri, webSocketSocialLinks: token.webSocketSocialLinks)
            
            // Step 3: Create final enhanced pair
            let finalPair = basePair.withEnhancedMetadata(enhancedInfo)
            
            return (finalPair, enhancedInfo)
        }.value
        
        // Step 4: Add to pairs list on main thread
        await MainActor.run {
            let (finalPair, enhancedInfo) = result
            
            // Double-check it hasn't been added already and we're not paused
            guard !self.pairs.contains(where: { $0.id == token.mint }) && !self.isPaused else {
                print("   ❌ Token already exists or feed is paused - skipping")
                self.isProcessingIPFS = false
                return
            }
            
            self.pairs.insert(finalPair, at: 0)
            
            // Log enhancement results
            if let metadata = enhancedInfo.ipfsMetadata {
                print("   ✅ Added \(token.symbol) with IPFS metadata:")
                print("      Name: \(metadata.name ?? "N/A")")
                print("      Description: \(metadata.description?.prefix(50) ?? "None")...")
                print("      Image: \(enhancedInfo.resolvedImageURL != nil ? "✅" : "❌")")
                print("      Verified: \(enhancedInfo.verified ? "✅" : "❌")")
            } else {
                print("   ✅ Added \(token.symbol) (no IPFS metadata found)")
            }
            
            // Keep only the latest 200 pairs
            if self.pairs.count > 200 {
                self.pairs = Array(self.pairs.prefix(200))
            }
            
            self.lastUpdate = Date()
            self.isProcessingIPFS = false
            
            // Notify sniper with enhanced token information
            let enhancedToken = EnhancedTokenForSniper(
                token: token,
                enhancedMetadata: enhancedInfo
            )
            
            print("🎯 Posting enhanced token notification for sniper: \(token.symbol)")
            NotificationCenter.default.post(
                name: NSNotification.Name("EnhancedTokenCreated"),
                object: enhancedToken
            )
        }
    }
    
    /// Enhance pairs with IPFS metadata (run in background)
    func enhancePairsWithIPFS() async {
        guard !pairs.isEmpty else { return }
        
        print("🌐 Starting IPFS enhancement for \(pairs.count) pairs...")
        
        // Enhance up to 10 most recent pairs to avoid overwhelming IPFS gateways
        let pairsToEnhance = Array(pairs.prefix(10))
        
        for (index, pair) in pairsToEnhance.enumerated() {
            // Check if paused before each enhancement
            guard !isPaused else {
                print("⏸️ IPFS enhancement paused")
                return
            }
            
            print("🔍 Enhancing pair \(index + 1)/\(pairsToEnhance.count): \(pair.baseToken.symbol)")
            
            let enhancedInfo = await ipfsService.enhanceTokenInfo(pair.baseToken)
            
            await MainActor.run {
                // Find and update the pair if it still exists
                if let pairIndex = self.pairs.firstIndex(where: { $0.id == pair.id }) {
                    let enhancedPair = pair.withEnhancedMetadata(enhancedInfo)
                    self.pairs[pairIndex] = enhancedPair
                    
                    if enhancedInfo.ipfsMetadata != nil {
                        print("✅ Enhanced \(pair.baseToken.symbol) with IPFS metadata")
                    }
                }
            }
            
            // Small delay to be respectful to IPFS gateways
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        print("🎉 IPFS enhancement completed")
    }
    
    /// Get IPFS cache statistics
    func getIPFSCacheStats() -> (metadataCount: Int, imageCount: Int) {
        return ipfsService.getCacheStats()
    }
    
    /// Clear IPFS cache
    func clearIPFSCache() {
        ipfsService.clearCache()
    }
    
    
    // MARK: - Real API Methods
    
    /// Load real pairs from APIs
    func loadRealPairs() async {
        do {
            // Get latest Solana pairs from DexScreener
            let latestPairs = try await apiService.getLatestSolanaPairs()
            
            await MainActor.run {
                self.pairs = Array(latestPairs.prefix(100))
                self.lastUpdate = Date()
                self.apiErrorMessage = nil
                self.isUsingRealAPI = true
            }
            
        } catch {
            await MainActor.run {
                self.apiErrorMessage = "API Error: \(error.localizedDescription)"
                self.isUsingRealAPI = false
                // Clear pairs if API fails
                self.pairs = []
            }
        }
    }
    
    /// Scan for new pairs using real APIs (focused on genuinely new tokens)
    func scanForRealPairs() async {
        guard isUsingRealAPI else { return }
        
        // Check if paused before doing any work
        guard !isPaused else {
            print("⏸️ Feed paused - skipping API scan")
            return
        }
        
        print("🔄 Scanning for genuinely new pairs...")
        
        do {
            // Get newest pairs from multiple sources
            let newPairs = try await apiService.getLatestSolanaPairs()
            
            // Filter for genuinely new pairs that we haven't seen before
            let unseenPairs = newPairs.filter { newPair in
                !self.pairs.contains(where: { $0.id == newPair.id })
            }
            
            // Further filter for recent and quality pairs
            let qualityPairs = unseenPairs.filter { pair in
                let age = pair.age
                let hasGoodLiquidity = pair.dex == "pump.fun" || pair.liquidity >= minLiquidity
                let isRecentEnough = age < 7200 // Less than 2 hours old
                let isDEXAllowed = selectedDEXs.contains(pair.dex)
                
                return isRecentEnough && hasGoodLiquidity && isDEXAllowed
            }
            
            await MainActor.run {
                // Double-check pause state before updating UI
                guard !self.isPaused else {
                    print("⏸️ Feed paused - skipping pair updates")
                    return
                }
                if !qualityPairs.isEmpty {
                    print("✅ Adding \(qualityPairs.count) new quality pairs")
                    
                    // Add new pairs to the beginning
                    for newPair in qualityPairs.reversed() {
                        self.pairs.insert(newPair, at: 0)
                    }
                    
                    // Keep only the latest 150 pairs
                    if self.pairs.count > 150 {
                        self.pairs = Array(self.pairs.prefix(150))
                    }
                } else {
                    print("ℹ️ No new quality pairs found in this scan")
                }
                
                self.lastUpdate = Date()
                self.apiErrorMessage = nil
            }
            
        } catch {
            await MainActor.run {
                self.apiErrorMessage = "Scan Error: \(error.localizedDescription)"
                print("Pair scanning error: \(error)")
            }
        }
    }
    
    /// Search for pairs using real API
    func searchPairs(query: String) async {
        guard isUsingRealAPI else { return }
        
        do {
            let searchResults = try await apiService.searchPairs(query: query)
            
            await MainActor.run {
                self.pairs = searchResults
                self.lastUpdate = Date()
                self.apiErrorMessage = nil
            }
            
        } catch {
            await MainActor.run {
                self.apiErrorMessage = "Search Error: \(error.localizedDescription)"
            }
        }
    }
    
    /// Get specific pair details
    func getPairDetails(address: String) async -> TradingPair? {
        guard isUsingRealAPI else { return nil }
        
        do {
            return try await apiService.getPair(address: address)
        } catch {
            await MainActor.run {
                self.apiErrorMessage = "Error getting pair details: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    // MARK: - Pump.fun WebSocket Integration
    
    private var processedTokenMints: Set<String> = []
    
    private func setupWebSocketObservers() {
        // Monitor PumpPortal WebSocket token feed and convert to TradingPairs
        webSocketManager.$newTokens
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tokens in
                guard let self = self else { return }
                
                print("🔄 WebSocket observer triggered with \(tokens.count) total tokens")
                
                // Only process if we have tokens, are scanning, and not paused
                guard !tokens.isEmpty && self.isScanning && !self.isPaused else { 
                    if self.isPaused {
                        print("⏸️ Feed paused - holding \(tokens.count) tokens")
                    } else {
                        print("⏸️ Not processing tokens - scanning: \(self.isScanning), tokens: \(tokens.count)")
                    }
                    return 
                }
                
                // Filter out tokens we've already processed
                let unprocessedTokens = tokens.filter { token in
                    !self.processedTokenMints.contains(token.mint)
                }
                
                print("🔍 Found \(unprocessedTokens.count) new unprocessed tokens (out of \(tokens.count) total)")
                
                // Convert to TradingPairs
                for token in unprocessedTokens {
                    // Mark as processed first to prevent duplicates
                    self.processedTokenMints.insert(token.mint)
                    
                    // Check if we already have this token in pairs
                    if !self.pairs.contains(where: { $0.id == token.mint }) {
                        print("🔍 Processing new token: \(token.symbol) - gathering IPFS metadata first...")
                        
                        // Process token with IPFS enhancement BEFORE adding to pairs
                        Task {
                            await self.processAndAddNewToken(token)
                        }
                    } else {
                        print("⚠️ Token \(token.symbol) already exists in pairs")
                    }
                }
                
                // Keep processed mints set manageable (last 1000 tokens)
                if self.processedTokenMints.count > 1000 {
                    let sortedMints = Array(self.processedTokenMints)
                    self.processedTokenMints = Set(sortedMints.suffix(500))
                }
                
                // Keep only the latest 200 pairs
                if self.pairs.count > 200 {
                    self.pairs = Array(self.pairs.prefix(200))
                }
                
                self.lastUpdate = Date()
                print("📊 Total pairs in scanner: \(self.pairs.count)")
            }
            .store(in: &cancellables)
        
        // Monitor Helius LaserStream for new DEX pairs (Raydium, Orca, etc.)
        // DISABLED: Currently not working, using only Pump.fun WebSocket
        /*
        heliusWebSocketManager.$newDetectedPairs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detectedPairs in
                guard let self = self else { return }
                
                print("🎯 Helius LaserStream detected \(detectedPairs.count) new pairs")
                
                // Only add pairs if not paused
                guard !self.isPaused else {
                    print("⏸️ Feed paused - holding \(detectedPairs.count) Helius pairs")
                    return
                }
                
                // Add newly detected DEX pairs to our main pairs list
                for pair in detectedPairs {
                    if !self.pairs.contains(where: { $0.id == pair.id }) {
                        self.pairs.insert(pair, at: 0)
                        print("✅ Added new DEX pair from LaserStream: \(pair.baseToken.symbol)/\(pair.quoteToken.symbol)")
                    }
                }
                
                // Keep only the latest 200 pairs
                if self.pairs.count > 200 {
                    self.pairs = Array(self.pairs.prefix(200))
                }
                
                self.lastUpdate = Date()
            }
            .store(in: &cancellables)
        */
    }
    
    private func setupBlockchainMonitorObservers() {
        // Monitor blockchain-detected token events
        blockchainMonitor.$newTokenEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tokenEvents in
                guard let self = self else { return }
                
                print("🔗 Blockchain monitor detected \(tokenEvents.count) token events")
                
                // Only process if not paused
                guard !self.isPaused else {
                    print("⏸️ Feed paused - holding \(tokenEvents.count) blockchain events")
                    return
                }
                
                // Process recent token creation events (last 10)
                let recentEvents = Array(tokenEvents.suffix(10))
                
                for event in recentEvents {
                    // Check if we already have this token
                    if !self.pairs.contains(where: { $0.id == event.mint }) {
                        // Process blockchain token with IPFS enhancement
                        Task {
                            await self.processBlockchainTokenWithIPFS(event)
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Monitor blockchain-detected pool events
        blockchainMonitor.$newPoolEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] poolEvents in
                guard let self = self else { return }
                
                print("🏊 Blockchain monitor detected \(poolEvents.count) pool events")
                
                // Only process if not paused
                guard !self.isPaused else {
                    print("⏸️ Feed paused - holding \(poolEvents.count) pool events")
                    return
                }
                
                // Process recent pool creation events
                for event in Array(poolEvents.suffix(5)) {
                    print("✅ New \(event.dex) pool: \(event.tokenA.prefix(8))...\(event.tokenB.prefix(8))...")
                }
            }
            .store(in: &cancellables)
    }
    
    /// Process blockchain token with complete IPFS enhancement before adding to feed
    private func processBlockchainTokenWithIPFS(_ event: TokenCreationEvent) async {
        print("🔗 Processing blockchain token with IPFS: \(event.mint.prefix(8))...")
        
        // Enrich with metadata from blockchain monitor
        if let metadata = await blockchainMonitor.enrichTokenMetadata(mint: event.mint) {
            let tokenCreation = TokenCreation(
                mint: event.mint,
                name: metadata.name ?? "Unknown",
                symbol: metadata.symbol ?? "UNKNOWN",
                description: metadata.description,
                image: metadata.image,
                createdTimestamp: event.blockTime.timeIntervalSince1970 * 1000,
                creator: event.authority,
                totalSupply: Double(event.supply ?? "0"),
                initialLiquidity: nil,
                raydiumPool: nil,
                complete: false,
                metadataUri: metadata.externalUrl, // Use external URL as metadata URI
                webSocketSocialLinks: nil, // No WebSocket social links from blockchain events
                // Pump.fun specific fields - nil for blockchain events
                marketCapSol: nil,
                solAmount: nil,
                initialBuy: nil,
                vSolInBondingCurve: nil,
                vTokensInBondingCurve: nil
            )
            
            // Process with full IPFS enhancement
            await processAndAddNewToken(tokenCreation)
        } else {
            print("   ❌ Failed to enrich blockchain token metadata")
        }
    }
    
    private func processBlockchainTokenEvent(_ event: TokenCreationEvent) async {
        print("🔗 Processing blockchain token event: \(event.mint.prefix(8))...")
        
        // Enrich with metadata from blockchain monitor
        if let metadata = await blockchainMonitor.enrichTokenMetadata(mint: event.mint) {
            let tokenCreation = TokenCreation(
                mint: event.mint,
                name: metadata.name ?? "Unknown",
                symbol: metadata.symbol ?? "UNKNOWN",
                description: metadata.description,
                image: metadata.image,
                createdTimestamp: event.blockTime.timeIntervalSince1970 * 1000,
                creator: event.authority,
                totalSupply: Double(event.supply ?? "0"),
                initialLiquidity: nil,
                raydiumPool: nil,
                complete: false,
                metadataUri: metadata.externalUrl, // Use external URL as metadata URI
                webSocketSocialLinks: nil, // No WebSocket social links from blockchain events
                // Pump.fun specific fields - nil for blockchain events
                marketCapSol: nil,
                solAmount: nil,
                initialBuy: nil,
                vSolInBondingCurve: nil,
                vTokensInBondingCurve: nil
            )
            
            await MainActor.run {
                // Check pause state before updating pairs
                guard !self.isPaused else {
                    print("⏸️ Feed paused - skipping blockchain token addition")
                    return
                }
                
                let newPair = self.convertTokenToTradingPair(tokenCreation)
                
                if !self.pairs.contains(where: { $0.id == newPair.id }) {
                    self.pairs.insert(newPair, at: 0)
                    print("✅ Added blockchain-detected token: \(newPair.baseToken.symbol)")
                    
                    // Keep only the latest 200 pairs
                    if self.pairs.count > 200 {
                        self.pairs = Array(self.pairs.prefix(200))
                    }
                    
                    self.lastUpdate = Date()
                }
            }
        }
    }
    
    private func convertTokenToTradingPair(_ token: TokenCreation) -> TradingPair {
        // Convert SOL to USD (using current SOL price ~$20-150, let's use $100 as reasonable estimate)
        let solToUsd = 100.0
        
        // Use only real pump.fun data - no fallbacks or estimates
        let liquidityInSol = token.vSolInBondingCurve ?? 0.0
        let liquidityInUsd = liquidityInSol * solToUsd
        
        // Use real market cap data only
        let marketCapInUsd: Double
        if let marketCapSol = token.marketCapSol {
            marketCapInUsd = marketCapSol * solToUsd
        } else {
            marketCapInUsd = 0.0 // No data = show 0, don't estimate
        }
        
        // Fix volume calculation - use only single transaction amounts, not cumulative
        let volume24h: Double
        if let solAmount = token.solAmount {
            // Use just the single transaction amount, not cumulative
            volume24h = abs(solAmount) * solToUsd
        } else if let initialBuy = token.initialBuy {
            // Fallback to initial buy amount only
            volume24h = abs(initialBuy) * solToUsd
        } else {
            volume24h = 0.0 // No data = show 0, don't estimate
        }
        
        print("💰 REAL API DATA ONLY for \(token.symbol):")
        print("   vSolInBondingCurve: \(liquidityInSol) SOL")
        print("   Liquidity USD: $\(String(format: "%.2f", liquidityInUsd))")
        print("   marketCapSol: \(token.marketCapSol ?? 0) SOL")
        print("   Market Cap USD: $\(String(format: "%.2f", marketCapInUsd))")
        print("   solAmount: \(token.solAmount ?? 0) SOL")
        print("   initialBuy: \(token.initialBuy ?? 0) SOL")
        print("   Single Transaction Volume USD: $\(String(format: "%.2f", volume24h))")
        
        // Cap unrealistic values
        let cappedVolume = min(volume24h, 50000.0) // Cap at $50K per transaction
        let cappedMarketCap = min(marketCapInUsd, 10000000.0) // Cap at $10M market cap
        let cappedLiquidity = min(liquidityInUsd, 1000000.0) // Cap at $1M liquidity
        
        if cappedVolume != volume24h {
            print("   ⚠️ Volume capped from $\(String(format: "%.2f", volume24h)) to $\(String(format: "%.2f", cappedVolume))")
        }
        if cappedMarketCap != marketCapInUsd {
            print("   ⚠️ Market cap capped from $\(String(format: "%.2f", marketCapInUsd)) to $\(String(format: "%.2f", cappedMarketCap))")
        }
        if cappedLiquidity != liquidityInUsd {
            print("   ⚠️ Liquidity capped from $\(String(format: "%.2f", liquidityInUsd)) to $\(String(format: "%.2f", cappedLiquidity))")
        }
        
        return TradingPair(
            id: token.mint,
            address: token.mint,
            baseToken: TokenInfo(
                address: token.mint,
                symbol: token.symbol,
                name: token.name,
                decimals: 9,
                logoURI: token.image
            ),
            quoteToken: TokenInfo(
                address: "So11111111111111111111111111111111111111112",
                symbol: "SOL",
                name: "Solana",
                decimals: 9,
                logoURI: nil
            ),
            dex: "pump.fun",
            liquidity: cappedLiquidity,
            volume24h: cappedVolume,
            priceChange24h: 0.0, // No real price change data available yet
            marketCap: cappedMarketCap,
            createdAt: token.createdDate,
            migrationStatus: .preMigration, // New tokens start as pre-migration
            riskScore: calculateRiskScore(for: token),
            holderCount: nil, // No real holder data available
            topHolderPercent: nil, // No real holder distribution data available
            enhancedMetadata: nil // Will be populated later when IPFS enhancement is done
        )
    }
    
    
    private func calculateRiskScore(for token: TokenCreation) -> Double {
        var score: Double = 30 // Base score for new tokens
        
        // Adjust based on initial liquidity
        if let liquidity = token.initialLiquidity {
            if liquidity > 10 { score -= 10 }
            if liquidity > 50 { score -= 10 }
            if liquidity < 1 { score += 20 }
        } else {
            score += 15 // No liquidity info = higher risk
        }
        
        // Adjust based on description quality
        if token.description?.count ?? 0 < 20 {
            score += 10 // Poor/no description = higher risk
        }
        
        // Adjust based on token name patterns
        let riskyPatterns = ["moon", "rocket", "100x", "gem", "diamond"]
        if riskyPatterns.contains(where: { token.name.lowercased().contains($0) }) {
            score += 15
        }
        
        return min(100, max(0, score))
    }
    
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Pair Scanner View
struct PairScannerView: View {
    @ObservedObject var pairManager: PairScannerManager
    let walletManager: WalletManager?
    let sniperEngine: SniperEngine?
    @State private var searchText = ""
    @State private var sortBy: SortOption = .newest
    @State private var showFilters = false
    
    init(pairManager: PairScannerManager, walletManager: WalletManager? = nil, sniperEngine: SniperEngine? = nil) {
        self.pairManager = pairManager
        self.walletManager = walletManager
        self.sniperEngine = sniperEngine
        
        print("🔧 PairScannerView initialized with:")
        print("   WalletManager: \(walletManager != nil ? "✅ Available" : "❌ Nil")")
        print("   SniperEngine: \(sniperEngine != nil ? "✅ Available" : "❌ Nil")")
    }
    
    enum SortOption: String, CaseIterable {
        case newest = "Newest"
        case liquidity = "Liquidity"
        case volume = "Volume"
        case marketCap = "Market Cap"
        case priceChange = "Price Change"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            PairScannerHeader(
                pairManager: pairManager,
                searchText: $searchText,
                sortBy: $sortBy,
                showFilters: $showFilters
            )
            
            Divider()
            
            // Filters Panel (if shown)
            if showFilters {
                PairScannerFilters(pairManager: pairManager)
                Divider()
            }
            
            // Pairs List
            if filteredPairs.isEmpty {
                ContentUnavailableView(
                    "No Pairs Found",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Adjust your filters or wait for new pairs to be discovered")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredPairs) { pair in
                            PairCard(pair: pair, walletManager: walletManager, sniperEngine: sniperEngine, pairManager: pairManager)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.8)),
                                    removal: .opacity.combined(with: .move(edge: .trailing))
                                ))
                        }
                    }
                    .padding()
                    .animation(.easeInOut(duration: 0.4), value: filteredPairs.count)
                }
                .onHover { isHovering in
                    if isHovering {
                        pairManager.pauseFeed()
                    } else {
                        pairManager.resumeFeed()
                    }
                }
                .overlay(
                    // Visual feedback for paused state
                    Group {
                        if pairManager.isPaused {
                            VStack {
                                HStack {
                                    Spacer()
                                    HStack(spacing: 8) {
                                        Image(systemName: "pause.circle.fill")
                                            .foregroundColor(.padraigOrange)
                                            .rotationEffect(.degrees(pairManager.isPaused ? 360 : 0))
                                            .animation(.easeInOut(duration: 0.5), value: pairManager.isPaused)
                                        Text("Feed Paused")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(PadraigTheme.primaryText)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.padraigOrange.opacity(0.15))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.padraigOrange.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                    .scaleEffect(pairManager.isPaused ? 1.0 : 0.8)
                                    .shadow(color: Color.padraigOrange.opacity(0.3), radius: 4, x: 0, y: 2)
                                    .padding(.trailing, 16)
                                    .padding(.top, 16)
                                }
                                Spacer()
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.8)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            ))
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: pairManager.isPaused)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private var filteredPairs: [TradingPair] {
        var filtered = pairManager.pairs
        
        // Search filter
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.baseToken.symbol.localizedCaseInsensitiveContains(searchText) ||
                $0.baseToken.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // DEX filter
        filtered = filtered.filter { pair in
            pairManager.selectedDEXs.contains(pair.dex)
        }
        
        // Migration status filter
        filtered = filtered.filter { pair in
            pairManager.selectedMigrationStatus.contains(pair.migrationStatus)
        }
        
        // Liquidity filter - be more lenient for pump.fun tokens
        filtered = filtered.filter { pair in
            if pair.dex == "pump.fun" {
                // Allow pump.fun tokens with any liquidity (including 0)
                return true
            } else {
                // Apply normal liquidity filter for other DEXs
                return pair.liquidity >= pairManager.minLiquidity
            }
        }
        
        // Age filter
        let maxAgeSeconds = TimeInterval(pairManager.maxAge * 3600)
        filtered = filtered.filter { pair in
            pair.age <= maxAgeSeconds
        }
        
        // Sort by selected option
        switch sortBy {
        case .newest:
            filtered.sort { $0.createdAt > $1.createdAt }
        case .liquidity:
            filtered.sort { $0.liquidity > $1.liquidity }
        case .volume:
            filtered.sort { $0.volume24h > $1.volume24h }
        case .marketCap:
            filtered.sort { ($0.marketCap ?? 0) > ($1.marketCap ?? 0) }
        case .priceChange:
            filtered.sort { $0.priceChange24h > $1.priceChange24h }
        }
        
        return filtered
    }
}