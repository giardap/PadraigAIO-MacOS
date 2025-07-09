//
//  DataModels.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/24/25.
//

import Foundation
import SwiftData

// MARK: - Wallet Management
@Model
final class Wallet {
    var id: UUID
    var name: String
    var publicKey: String
    var apiKey: String?
    var isActive: Bool
    var balance: Double
    var createdAt: Date
    var lastUpdated: Date
    
    init(name: String, publicKey: String, apiKey: String? = nil) {
        self.id = UUID()
        self.name = name
        self.publicKey = publicKey
        self.apiKey = apiKey
        self.isActive = true
        self.balance = 0.0
        self.createdAt = Date()
        self.lastUpdated = Date()
    }
}

// MARK: - Sniper Configuration
@Model
final class SniperConfig {
    var id: UUID
    var name: String
    var isActive: Bool
    
    // Criteria - stored as comma-separated strings
    private var symbolKeywordsString: String
    private var descriptionKeywordsString: String
    private var blacklistString: String
    private var twitterAccountsString: String // New field for Twitter accounts
    var minLiquidity: Double
    var maxSupply: Double
    var creatorAddress: String?
    
    // Trading Settings
    var buyAmount: Double
    var slippage: Double
    var maxGas: Double
    private var selectedWalletsString: String
    var staggerDelay: Int
    var tradingPool: String // "pump" or "bonk"
    
    // Computed properties for array access
    var symbolKeywords: [String] {
        get {
            guard !symbolKeywordsString.isEmpty else { return [] }
            return symbolKeywordsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        set {
            symbolKeywordsString = newValue.filter { !$0.isEmpty }.joined(separator: ",")
        }
    }
    
    var descriptionKeywords: [String] {
        get {
            guard !descriptionKeywordsString.isEmpty else { return [] }
            return descriptionKeywordsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        set {
            descriptionKeywordsString = newValue.filter { !$0.isEmpty }.joined(separator: ",")
        }
    }
    
    // Legacy computed property for backwards compatibility
    var keywords: [String] {
        get {
            return symbolKeywords + descriptionKeywords
        }
        set {
            // When setting legacy keywords, put them in symbol keywords for now
            symbolKeywords = newValue
        }
    }
    
    var blacklist: [String] {
        get {
            guard !blacklistString.isEmpty else { return [] }
            return blacklistString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        set {
            blacklistString = newValue.filter { !$0.isEmpty }.joined(separator: ",")
        }
    }
    
    var twitterAccounts: [String] {
        get {
            guard !twitterAccountsString.isEmpty else { return [] }
            return twitterAccountsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        set {
            twitterAccountsString = newValue.filter { !$0.isEmpty }.joined(separator: ",")
        }
    }
    
    var selectedWallets: [UUID] {
        get {
            guard !selectedWalletsString.isEmpty else { return [] }
            return selectedWalletsString.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .compactMap { UUID(uuidString: $0) }
        }
        set {
            selectedWalletsString = newValue.map { $0.uuidString }.joined(separator: ",")
        }
    }
    
    // Safety Settings
    var maxDailySpend: Double
    var cooldownPeriod: Int
    var requireConfirmation: Bool
    var enabled: Bool
    
    var createdAt: Date
    var lastUpdated: Date
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.isActive = false
        
        // Default criteria
        self.symbolKeywordsString = ""
        self.descriptionKeywordsString = ""
        self.blacklistString = ""
        self.twitterAccountsString = ""
        self.minLiquidity = 5.0
        self.maxSupply = 1000000000
        self.creatorAddress = nil
        
        // Default trading settings
        self.buyAmount = 0.1
        self.slippage = 10.0
        self.maxGas = 0.01
        self.selectedWalletsString = ""
        self.staggerDelay = 100
        self.tradingPool = "pump"
        
        // Default safety settings
        self.maxDailySpend = 1.0
        self.cooldownPeriod = 30
        self.requireConfirmation = true
        self.enabled = false
        
        self.createdAt = Date()
        self.lastUpdated = Date()
    }
}

// MARK: - Token Data
struct TokenCreation: Codable, Identifiable {
    let id = UUID()
    let mint: String
    let name: String
    let symbol: String
    let description: String?
    let image: String?
    let createdTimestamp: TimeInterval
    let creator: String?
    let totalSupply: Double?
    let initialLiquidity: Double?
    let raydiumPool: String?
    let complete: Bool?
    let metadataUri: String? // Added metadata URI field for IPFS
    let webSocketSocialLinks: [String]? // Added WebSocket social links
    
    // Pump.fun specific financial data
    let marketCapSol: Double?
    let solAmount: Double?
    let initialBuy: Double?
    let vSolInBondingCurve: Double?
    let vTokensInBondingCurve: Double?
    
    var createdDate: Date {
        Date(timeIntervalSince1970: createdTimestamp / 1000)
    }
}

// MARK: - Enhanced Token for Sniper
struct EnhancedTokenForSniper {
    let token: TokenCreation
    let enhancedMetadata: EnhancedTokenInfo?
    
    // Combined social links from all sources
    var allSocialLinks: [String] {
        var links: [String] = []
        
        // Add WebSocket social links
        if let webSocketLinks = token.webSocketSocialLinks {
            links.append(contentsOf: webSocketLinks)
        }
        
        // Add IPFS social links from enhanced metadata
        if let enhancedLinks = enhancedMetadata?.socialLinks {
            links.append(contentsOf: enhancedLinks)
        }
        
        return Array(Set(links)) // Remove duplicates
    }
}

// MARK: - Transaction History
@Model
final class TransactionRecord {
    var id: UUID
    var tokenMint: String
    var tokenName: String
    var tokenSymbol: String
    var transactionType: String // "buy", "sell", "failed"
    var amount: Double
    var price: Double
    var slippage: Double
    var gasUsed: Double
    var walletUsed: String
    var txSignature: String?
    var success: Bool
    var errorMessage: String?
    var timestamp: Date
    
    init(tokenMint: String, tokenName: String, tokenSymbol: String, transactionType: String, amount: Double, price: Double, slippage: Double, gasUsed: Double, walletUsed: String) {
        self.id = UUID()
        self.tokenMint = tokenMint
        self.tokenName = tokenName
        self.tokenSymbol = tokenSymbol
        self.transactionType = transactionType
        self.amount = amount
        self.price = price
        self.slippage = slippage
        self.gasUsed = gasUsed
        self.walletUsed = walletUsed
        self.success = false
        self.timestamp = Date()
    }
}

// MARK: - Sniper Statistics
@Model
final class SniperStats {
    var id: UUID
    var totalAttempts: Int
    var successfulSnipes: Int
    var failedSnipes: Int
    var totalSpent: Double
    var totalProfit: Double
    var averageSpeed: Double // ms from detection to purchase
    var lastSnipeTime: Date?
    var dailySpent: Double
    var lastResetDate: Date
    
    init() {
        self.id = UUID()
        self.totalAttempts = 0
        self.successfulSnipes = 0
        self.failedSnipes = 0
        self.totalSpent = 0.0
        self.totalProfit = 0.0
        self.averageSpeed = 0.0
        self.lastSnipeTime = nil
        self.dailySpent = 0.0
        self.lastResetDate = Date()
    }
    
    var successRate: Double {
        guard totalAttempts > 0 else { return 0.0 }
        return Double(successfulSnipes) / Double(totalAttempts) * 100
    }
}

