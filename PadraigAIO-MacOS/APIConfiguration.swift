//
//  APIConfiguration.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/26/25.
//

import Foundation

// MARK: - API Configuration
struct APIConfiguration {
    // MARK: - Helius Configuration
    // Get your free API key from: https://helius.xyz
    // Helius provides comprehensive Solana blockchain data including:
    // - Real-time token creation events
    // - Liquidity pool monitoring  
    // - Enhanced transaction parsing
    // - Token metadata enrichment
    static let heliusAPIKey = "e3b54e60-daee-442f-8b75-1893c5be291f"
    
    // MARK: - QuickNode Configuration
    // QuickNode Metis add-on provides new pool detection
    // Get access at: https://marketplace.quicknode.com/add-on/metis
    static let quickNodeAPIKey = "" // Add your QuickNode API key here
    static let quickNodeEndpoint = "" // Add your QuickNode endpoint here
    
    // MARK: - Solana RPC Configuration
    // Public RPC endpoints (rate limited)
    static let publicSolanaRPC = "https://api.mainnet-beta.solana.com"
    static let publicSolanaWebSocket = "wss://api.mainnet-beta.solana.com"
    
    // Private RPC providers (recommended for production)
    static let heliusRPC = "https://rpc.helius.xyz/?api-key=\(heliusAPIKey)"
    static let heliusWebSocket = "wss://atlas-mainnet.helius-rpc.com/?api-key=\(heliusAPIKey)"
    
    // MARK: - Feature Flags
    static let useHeliusAPI = !heliusAPIKey.isEmpty
    static let useQuickNodeAPI = !quickNodeAPIKey.isEmpty
    static let enableBlockchainMonitoring = true
    static let enableAdvancedFiltering = true
    
    // MARK: - Performance Settings
    static let maxTokensToTrack = 1000
    static let maxPoolsToTrack = 500
    static let tokenCleanupInterval: TimeInterval = 3600 // 1 hour
    static let poolMonitoringInterval: TimeInterval = 30 // 30 seconds
    
    // MARK: - Risk Analysis Settings
    static let defaultRiskThreshold = 70.0
    static let scamDetectionEnabled = true
    static let minimumLiquidityThreshold = 1000.0 // USD
    static let maximumRiskScore = 95.0
    
    // MARK: - Notification Settings
    static let enableNewTokenNotifications = true
    static let enableNewPoolNotifications = true
    static let enableRiskAlerts = true
    
    // MARK: - Helper Methods
    static var isHeliusConfigured: Bool {
        return !heliusAPIKey.isEmpty
    }
    
    static var isQuickNodeConfigured: Bool {
        return !quickNodeAPIKey.isEmpty && !quickNodeEndpoint.isEmpty
    }
    
    static var preferredRPCEndpoint: String {
        return isHeliusConfigured ? heliusRPC : publicSolanaRPC
    }
    
    static var preferredWebSocketEndpoint: String {
        return isHeliusConfigured ? heliusWebSocket : publicSolanaWebSocket
    }
    
    // MARK: - Setup Instructions
    static func printSetupInstructions() {
        print("🔧 === API SETUP INSTRUCTIONS ===")
        print("To enable advanced blockchain monitoring:")
        print("")
        print("1. HELIUS API (Recommended):")
        print("   - Visit: https://helius.xyz")
        print("   - Create free account (100,000 requests/month)")
        print("   - Copy API key to APIConfiguration.heliusAPIKey")
        print("   - Enables: Real-time token detection, metadata enrichment")
        print("")
        print("2. QUICKNODE METIS (Optional):")
        print("   - Visit: https://marketplace.quicknode.com/add-on/metis") 
        print("   - Subscribe to Metis add-on")
        print("   - Copy API key and endpoint to APIConfiguration")
        print("   - Enables: Enhanced new pool detection")
        print("")
        print("3. CURRENT STATUS:")
        print("   - Helius: \(isHeliusConfigured ? "✅ Configured" : "❌ Not configured")")
        print("   - QuickNode: \(isQuickNodeConfigured ? "✅ Configured" : "❌ Not configured")")
        print("   - Blockchain Monitoring: \(enableBlockchainMonitoring ? "✅ Enabled" : "❌ Disabled")")
        print("=====================================")
    }
}

// MARK: - Monitoring Configuration
struct MonitoringConfig {
    // Programs to monitor for token creation
    static let monitoredPrograms = [
        SolanaPrograms.splToken,
        SolanaPrograms.splTokenMetadata,
        SolanaPrograms.raydiumAMM,
        SolanaPrograms.raydiumCPMM,
        SolanaPrograms.orcaWhirlpool,
        SolanaPrograms.jupiterV6,
        SolanaPrograms.pumpFunProgram
    ]
    
    // Token patterns to watch for (memecoins)
    static let memecoinPatterns = [
        "moon", "rocket", "gem", "diamond", "pump", "doge", "pepe", "shib", "inu",
        "safe", "baby", "mini", "chad", "based", "alpha", "sigma", "gigachad",
        "wojak", "apu", "bobo", "cope", "hopium", "wagmi", "ngmi", "fud"
    ]
    
    // Risk indicators
    static let riskPatterns = [
        "rugpull", "scam", "honeypot", "fake", "duplicate", "copy", "clone"
    ]
    
    // Quality indicators  
    static let qualityIndicators = [
        "verified", "audited", "community", "dao", "protocol", "defi"
    ]
}