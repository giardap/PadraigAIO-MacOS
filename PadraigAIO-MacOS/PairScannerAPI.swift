//
//  PairScannerAPI.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/24/25.
//

import Foundation
import Combine

// MARK: - API Response Models
struct DexScreenerResponse: Codable {
    let schemaVersion: String
    let pairs: [DexScreenerPair]?
}

struct DexScreenerPair: Codable {
    let chainId: String
    let dexId: String
    let url: String
    let pairAddress: String
    let baseToken: DexScreenerToken
    let quoteToken: DexScreenerToken
    let priceNative: String?
    let priceUsd: String?
    let txns: DexScreenerTxns?
    let volume: DexScreenerVolume?
    let priceChange: DexScreenerPriceChange?
    let liquidity: DexScreenerLiquidity?
    let fdv: Double?
    let marketCap: Double?
    let pairCreatedAt: Int64?
    let info: DexScreenerInfo?
}

struct DexScreenerToken: Codable {
    let address: String
    let name: String
    let symbol: String
}

struct DexScreenerTxns: Codable {
    let m5: DexScreenerTxnCount?
    let h1: DexScreenerTxnCount?
    let h6: DexScreenerTxnCount?
    let h24: DexScreenerTxnCount?
}

struct DexScreenerTxnCount: Codable {
    let buys: Int
    let sells: Int
}

struct DexScreenerVolume: Codable {
    let h24: Double?
    let h6: Double?
    let h1: Double?
    let m5: Double?
}

struct DexScreenerPriceChange: Codable {
    let m5: Double?
    let h1: Double?
    let h6: Double?
    let h24: Double?
}

struct DexScreenerLiquidity: Codable {
    let usd: Double?
    let base: Double?
    let quote: Double?
}

struct DexScreenerInfo: Codable {
    let imageUrl: String?
    let websites: [DexScreenerWebsite]?
    let socials: [DexScreenerSocial]?
}

struct DexScreenerWebsite: Codable {
    let label: String?
    let url: String
}

struct DexScreenerSocial: Codable {
    let type: String
    let url: String
}

// MARK: - Jupiter API Models
struct JupiterPriceResponse: Codable {
    let data: [String: JupiterTokenPrice]
}

struct JupiterTokenPrice: Codable {
    let id: String
    let mintSymbol: String?
    let vsToken: String
    let vsTokenSymbol: String
    let price: Double
}

struct JupiterTokenListResponse: Codable {
    let tokens: [JupiterToken]
}

struct JupiterToken: Codable {
    let address: String
    let chainId: Int
    let decimals: Int
    let name: String
    let symbol: String
    let logoURI: String?
    let tags: [String]?
}

// MARK: - Pump.fun API Models
struct PumpFunResponse: Codable {
    let coins: [PumpFunToken]?
}

struct PumpFunToken: Codable {
    let mint: String
    let name: String
    let symbol: String
    let description: String?
    let image: String?
    let createdTimestamp: Int64
    let raydiumPool: String?
    let complete: Bool // Migration status
    let totalSupply: Int64?
    let decimals: Int?
    let marketCap: Double?
    let bondingCurve: String?
    let associatedBondingCurve: String?
}

// MARK: - API Service
class PairScannerAPIService: ObservableObject {
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    
    // API Endpoints
    private let dexScreenerBase = "https://api.dexscreener.com/latest/dex"
    private let jupiterPriceBase = "https://price.jup.ag/v4/price"
    private let jupiterTokensBase = "https://token.jup.ag/strict"
    private let pumpFunBase = "https://client-api-2-74b1891ee9f9.herokuapp.com"
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    // MARK: - DexScreener API Methods
    
    /// Get new pairs from DexScreener (using latest pairs API and new token strategies)
    func getLatestSolanaPairs() async throws -> [TradingPair] {
        print("🌐 Fetching latest Solana pairs from DexScreener...")
        
        var allPairs: [TradingPair] = []
        
        // Strategy 1: Get latest pairs for Solana chain
        do {
            let latestPairs = try await getLatestPairsForChain(chainId: "solana")
            allPairs.append(contentsOf: latestPairs)
            print("📊 Found \(latestPairs.count) latest Solana pairs")
        } catch {
            print("⚠️ Error fetching latest pairs: \(error)")
        }
        
        // Strategy 2: Search for very new tokens using common meme patterns
        let newTokenPatterns = ["moon", "pepe", "doge", "shib", "inu", "elon", "safe", "baby"]
        
        for pattern in newTokenPatterns.prefix(3) { // Limit to avoid rate limiting
            do {
                let pairs = try await searchPairs(query: pattern)
                // Filter to only very recent pairs (last 24 hours)
                let recentPairs = pairs.filter { pair in
                    let age = Date().timeIntervalSince(pair.createdAt)
                    return age < 86400 // Less than 24 hours old
                }
                allPairs.append(contentsOf: recentPairs)
                print("📊 Found \(recentPairs.count) recent pairs for '\(pattern)' pattern")
                
                // Small delay to avoid rate limiting
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            } catch {
                print("⚠️ Error searching for '\(pattern)': \(error)")
                continue
            }
        }
        
        // Strategy 3: Get pump.fun tokens and convert to trading pairs
        do {
            let pumpTokens = try await getPumpFunTokens(limit: 20, offset: 0)
            let pumpPairs = pumpTokens.compactMap { convertPumpTokenToTradingPair($0) }
            allPairs.append(contentsOf: pumpPairs)
            print("📊 Found \(pumpPairs.count) pump.fun tokens")
        } catch {
            print("⚠️ Error fetching pump.fun tokens: \(error)")
        }
        
        // Remove duplicates and sort by creation time (newest first)
        let uniquePairs = Dictionary(grouping: allPairs, by: { $0.address })
            .compactMapValues { $0.first }
            .values
            .sorted { $0.createdAt > $1.createdAt }
        
        let finalPairs = Array(uniquePairs.prefix(100))
        print("✅ Total unique new Solana pairs found: \(finalPairs.count)")
        
        return finalPairs
    }
    
    /// Get latest pairs for a specific chain
    func getLatestPairsForChain(chainId: String) async throws -> [TradingPair] {
        let urlString = "\(dexScreenerBase)/pairs/\(chainId)?sort=created_at&order=desc"
        print("🔍 Fetching latest pairs: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidQuery
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Latest pairs HTTP Status: \(httpResponse.statusCode)")
            }
            
            let decodedResponse = try decoder.decode(DexScreenerResponse.self, from: data)
            let tradingPairs = decodedResponse.pairs?.compactMap { convertDexScreenerPairToTradingPair($0) } ?? []
            
            return tradingPairs
        } catch {
            print("❌ Latest pairs error: \(error)")
            throw error
        }
    }
    
    /// Search for specific token pairs
    func searchPairs(query: String) async throws -> [TradingPair] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("❌ Failed to encode query: \(query)")
            throw APIError.invalidQuery
        }
        
        let urlString = "\(dexScreenerBase)/search/?q=\(encodedQuery)"
        print("🔍 Searching: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidQuery
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Search HTTP Status: \(httpResponse.statusCode)")
            }
            
            let decodedResponse = try decoder.decode(DexScreenerResponse.self, from: data)
            let tradingPairs = decodedResponse.pairs?.compactMap { convertDexScreenerPairToTradingPair($0) } ?? []
            print("🔍 Search for '\(query)' returned \(tradingPairs.count) pairs")
            
            return tradingPairs
        } catch {
            print("❌ Search error for '\(query)': \(error)")
            throw error
        }
    }
    
    /// Get specific pair by address
    func getPair(address: String) async throws -> TradingPair? {
        let url = URL(string: "\(dexScreenerBase)/pairs/solana/\(address)")!
        let (data, _) = try await session.data(from: url)
        
        let response = try decoder.decode(DexScreenerResponse.self, from: data)
        return response.pairs?.first.flatMap { convertDexScreenerPairToTradingPair($0) }
    }
    
    /// Get pairs for a specific token
    func getPairsForToken(address: String) async throws -> [TradingPair] {
        let url = URL(string: "\(dexScreenerBase)/tokens/\(address)")!
        let (data, _) = try await session.data(from: url)
        
        let response = try decoder.decode(DexScreenerResponse.self, from: data)
        return response.pairs?.compactMap { convertDexScreenerPairToTradingPair($0) } ?? []
    }
    
    // MARK: - Jupiter API Methods
    
    /// Get current prices for tokens
    func getTokenPrices(addresses: [String]) async throws -> [String: Double] {
        let addressString = addresses.joined(separator: ",")
        let url = URL(string: "\(jupiterPriceBase)?ids=\(addressString)")!
        
        let (data, _) = try await session.data(from: url)
        let response = try decoder.decode(JupiterPriceResponse.self, from: data)
        
        var prices: [String: Double] = [:]
        for (address, priceInfo) in response.data {
            prices[address] = priceInfo.price
        }
        return prices
    }
    
    /// Get Jupiter token list
    func getJupiterTokens() async throws -> [JupiterToken] {
        let url = URL(string: jupiterTokensBase)!
        let (data, _) = try await session.data(from: url)
        
        let tokens = try decoder.decode([JupiterToken].self, from: data)
        return tokens
    }
    
    // MARK: - Pump.fun API Methods
    
    /// Get latest tokens from Pump.fun
    func getPumpFunTokens(limit: Int = 50, offset: Int = 0) async throws -> [PumpFunToken] {
        let url = URL(string: "\(pumpFunBase)/coins?offset=\(offset)&limit=\(limit)&sort=created_timestamp&order=DESC")!
        
        let (data, _) = try await session.data(from: url)
        let tokens = try decoder.decode([PumpFunToken].self, from: data)
        return tokens
    }
    
    /// Get specific Pump.fun token
    func getPumpFunToken(mint: String) async throws -> PumpFunToken? {
        let url = URL(string: "\(pumpFunBase)/coins/\(mint)")!
        
        let (data, _) = try await session.data(from: url)
        let token = try decoder.decode(PumpFunToken.self, from: data)
        return token
    }
    
    /// Check migration status for Pump.fun tokens
    func checkMigrationStatus(mints: [String]) async throws -> [String: MigrationStatus] {
        var statuses: [String: MigrationStatus] = [:]
        
        // Check each token individually (Pump.fun doesn't have batch endpoint)
        for mint in mints {
            do {
                if let token = try await getPumpFunToken(mint: mint) {
                    if token.complete {
                        statuses[mint] = .migrated
                    } else if token.raydiumPool != nil {
                        statuses[mint] = .migrating
                    } else {
                        statuses[mint] = .preMigration
                    }
                }
            } catch {
                statuses[mint] = .failed
            }
        }
        
        return statuses
    }
    
    // MARK: - Conversion Methods
    
    private func convertPumpTokenToTradingPair(_ pumpToken: PumpFunToken) -> TradingPair? {
        print("🔄 Converting pump.fun token: \(pumpToken.symbol) (\(pumpToken.name))")
        
        // Calculate liquidity estimate (pump.fun uses bonding curve)
        let estimatedLiquidity = pumpToken.marketCap ?? 0.0
        
        // Convert timestamp
        let createdAt = Date(timeIntervalSince1970: TimeInterval(pumpToken.createdTimestamp / 1000))
        
        // Determine migration status
        let migrationStatus: MigrationStatus = pumpToken.complete ? .migrated : .preMigration
        
        // Calculate risk score for pump.fun tokens
        let riskScore = calculatePumpTokenRiskScore(pumpToken)
        
        let tradingPair = TradingPair(
            id: pumpToken.mint,
            address: pumpToken.mint,
            baseToken: TokenInfo(
                address: pumpToken.mint,
                symbol: pumpToken.symbol,
                name: pumpToken.name,
                decimals: pumpToken.decimals ?? 9,
                logoURI: pumpToken.image
            ),
            quoteToken: TokenInfo(
                address: "So11111111111111111111111111111111111111112",
                symbol: "SOL",
                name: "Solana",
                decimals: 9,
                logoURI: nil
            ),
            dex: "pump.fun",
            liquidity: estimatedLiquidity,
            volume24h: estimatedLiquidity * 0.3, // Conservative volume estimate
            priceChange24h: 0.0, // New tokens start with 0% change
            marketCap: pumpToken.marketCap,
            createdAt: createdAt,
            migrationStatus: migrationStatus,
            riskScore: riskScore,
            holderCount: nil, // Would need additional API call
            topHolderPercent: nil, // Would need additional API call
            enhancedMetadata: nil // Will be enhanced later if IPFS data available
        )
        
        print("✅ Converted pump token: \(tradingPair.baseToken.symbol) - Liq: $\(tradingPair.liquidity)")
        return tradingPair
    }
    
    private func calculatePumpTokenRiskScore(_ token: PumpFunToken) -> Double {
        var score = 70.0 // Higher base score for pump.fun tokens (riskier)
        
        // Market cap factor
        if let marketCap = token.marketCap {
            if marketCap < 1000 {
                score += 20
            } else if marketCap > 50000 {
                score -= 15
            }
        }
        
        // Description quality
        if let description = token.description {
            if description.count < 10 {
                score += 10
            } else if description.count > 100 {
                score -= 5
            }
        } else {
            score += 15 // No description = higher risk
        }
        
        // Migration status
        if token.complete {
            score -= 20 // Migrated tokens are less risky
        }
        
        // Age factor
        let age = Date().timeIntervalSince1970 - TimeInterval(token.createdTimestamp / 1000)
        if age < 3600 { // Less than 1 hour
            score += 15
        }
        
        return max(0, min(100, score))
    }
    
    private func convertDexScreenerPairToTradingPair(_ dexPair: DexScreenerPair) -> TradingPair? {
        print("🔄 Converting pair: \(dexPair.baseToken.symbol)/\(dexPair.quoteToken.symbol) on \(dexPair.dexId)")
        
        // Only process Solana pairs
        guard dexPair.chainId.lowercased() == "solana" else {
            print("⚠️ Skipping non-Solana pair: \(dexPair.chainId)")
            return nil
        }
        
        // Determine DEX from dexId
        let dexName = mapDexId(dexPair.dexId)
        print("📊 DEX: \(dexName), Liquidity: \(dexPair.liquidity?.usd ?? 0)")
        
        // Calculate risk score based on available data
        let riskScore = calculateRiskScore(pair: dexPair)
        
        // Determine migration status
        let migrationStatus = determineMigrationStatus(pair: dexPair)
        
        // Convert timestamp
        let createdAt = dexPair.pairCreatedAt.map { Date(timeIntervalSince1970: TimeInterval($0 / 1000)) } ?? Date()
        
        let tradingPair = TradingPair(
            id: dexPair.pairAddress,
            address: dexPair.pairAddress,
            baseToken: TokenInfo(
                address: dexPair.baseToken.address,
                symbol: dexPair.baseToken.symbol,
                name: dexPair.baseToken.name,
                decimals: 9, // Default, could be enhanced with more data
                logoURI: dexPair.info?.imageUrl
            ),
            quoteToken: TokenInfo(
                address: dexPair.quoteToken.address,
                symbol: dexPair.quoteToken.symbol,
                name: dexPair.quoteToken.name,
                decimals: 9,
                logoURI: nil
            ),
            dex: dexName,
            liquidity: dexPair.liquidity?.usd ?? 0,
            volume24h: dexPair.volume?.h24 ?? 0,
            priceChange24h: dexPair.priceChange?.h24 ?? 0,
            marketCap: dexPair.marketCap,
            createdAt: createdAt,
            migrationStatus: migrationStatus,
            riskScore: riskScore,
            holderCount: nil, // Would need additional API call
            topHolderPercent: nil, // Would need additional API call
            enhancedMetadata: nil // Will be enhanced later if IPFS data available
        )
        
        print("✅ Converted pair: \(tradingPair.baseToken.symbol) - Liq: $\(tradingPair.liquidity)")
        return tradingPair
    }
    
    private func mapDexId(_ dexId: String) -> String {
        switch dexId.lowercased() {
        case "raydium": return "raydium"
        case "orca": return "orca"
        case "pump": return "pump.fun"
        case "pumpswap": return "pump.fun"
        case "serum": return "serum"
        case "openbook": return "openbook"
        case "jupiter": return "jupiter"
        default: return dexId.lowercased()
        }
    }
    
    private func calculateRiskScore(pair: DexScreenerPair) -> Double {
        var score = 50.0 // Base score
        
        // Liquidity factor (lower liquidity = higher risk)
        if let liquidity = pair.liquidity?.usd {
            if liquidity < 1000 {
                score += 30
            } else if liquidity < 10000 {
                score += 20
            } else if liquidity > 100000 {
                score -= 20
            }
        }
        
        // Volume factor (low volume = higher risk)
        if let volume = pair.volume?.h24 {
            if volume < 1000 {
                score += 20
            } else if volume > 50000 {
                score -= 15
            }
        }
        
        // Age factor (very new = higher risk)
        if let createdAt = pair.pairCreatedAt {
            let age = Date().timeIntervalSince1970 - TimeInterval(createdAt / 1000)
            if age < 3600 { // Less than 1 hour
                score += 25
            } else if age < 86400 { // Less than 1 day
                score += 10
            }
        }
        
        // Price volatility (high volatility = higher risk)
        if let priceChange = pair.priceChange?.h24 {
            if abs(priceChange) > 100 {
                score += 15
            }
        }
        
        return max(0, min(100, score))
    }
    
    private func determineMigrationStatus(pair: DexScreenerPair) -> MigrationStatus {
        // This is simplified - would need to check against Pump.fun API
        switch pair.dexId.lowercased() {
        case "pump":
            return .preMigration
        case "raydium":
            // Check if it was recently migrated from Pump.fun
            if let age = pair.pairCreatedAt {
                let ageHours = (Date().timeIntervalSince1970 - TimeInterval(age / 1000)) / 3600
                return ageHours < 24 ? .migrated : .migrated
            }
            return .migrated
        default:
            return .migrated
        }
    }
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case invalidQuery
    case networkError(Error)
    case decodingError(Error)
    case rateLimited
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Invalid search query"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        case .rateLimited:
            return "API rate limit exceeded"
        case .noData:
            return "No data available"
        }
    }
}

