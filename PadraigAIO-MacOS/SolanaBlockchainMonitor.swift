//
//  SolanaBlockchainMonitor.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/26/25.
//

import Foundation
import Combine

// MARK: - Blockchain Event Models
struct TokenCreationEvent {
    let mint: String
    let authority: String
    let decimals: Int
    let supply: String?
    let freezeAuthority: String?
    let slot: UInt64
    let blockTime: Date
    let signature: String
}

struct LiquidityPoolEvent {
    let poolAddress: String
    let tokenA: String
    let tokenB: String
    let dex: String
    let initialLiquidityA: Double?
    let initialLiquidityB: Double?
    let slot: UInt64
    let blockTime: Date
    let signature: String
}

struct TokenMetadata {
    let mint: String
    let name: String?
    let symbol: String?
    let description: String?
    let image: String?
    let externalUrl: String?
    let creators: [TokenCreator]?
}

struct TokenCreator {
    let address: String
    let verified: Bool
    let share: Int
}

// MARK: - Solana Program IDs
enum SolanaPrograms {
    static let splToken = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    static let splTokenMetadata = "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
    static let raydiumAMM = "675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8"
    static let raydiumCPMM = "CPMMoo8L3F4NbTegBCKVNunggL7H1ZpdTHKxQB5qKP1C"
    static let orcaWhirlpool = "whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc"
    static let jupiterV6 = "JUP6LkbZbjS1jKKwapdHNy74zcZ3tLUZoi5QNyVTaV4"
    static let pumpFunProgram = "6EF8rrecthR5Dkzon8Nwu78hRvfCKubJ14M5uBEwF6P"
}

// MARK: - Helius API Models
struct HeliusTokenResponse: Codable {
    let mint: String
    let name: String?
    let symbol: String?
    let description: String?
    let imageUri: String?
    let metadataUri: String?
    let updateAuthority: String?
    let creators: [HeliusCreator]?
    let price: Double?
    let priceChange24h: Double?
    let volumeChange24h: Double?
    let supply: String?
    let decimals: Int?
}

struct HeliusCreator: Codable {
    let address: String
    let verified: Bool
    let share: Int
}

struct HeliusNewPoolResponse: Codable {
    let signature: String
    let slot: UInt64
    let blockTime: Int64
    let programId: String
    let accounts: [String]
    let instructions: [HeliusInstruction]
}

struct HeliusInstruction: Codable {
    let programId: String
    let accounts: [String]
    let data: String
    let innerInstructions: [HeliusInstruction]?
}

// MARK: - QuickNode API Models
struct QuickNodeNewPoolsResponse: Codable {
    let success: Bool
    let data: [QuickNodePool]?
    let error: String?
}

struct QuickNodePool: Codable {
    let poolAddress: String
    let tokenA: QuickNodeToken
    let tokenB: QuickNodeToken
    let dex: String
    let liquidityA: String?
    let liquidityB: String?
    let createdAt: Int64
    let signature: String
}

struct QuickNodeToken: Codable {
    let mint: String
    let name: String?
    let symbol: String?
    let decimals: Int
    let logoUri: String?
}

// MARK: - Solana Blockchain Monitor
class SolanaBlockchainMonitor: ObservableObject {
    @Published var newTokenEvents: [TokenCreationEvent] = []
    @Published var newPoolEvents: [LiquidityPoolEvent] = []
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()
    private let apiKey: String
    private let rpcEndpoint: String
    private let useHelius: Bool
    
    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
        
        static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected),
                 (.connecting, .connecting),
                 (.connected, .connected):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    init(apiKey: String = "", useHelius: Bool = true) {
        self.apiKey = apiKey
        self.useHelius = useHelius
        self.rpcEndpoint = useHelius ? 
            "wss://atlas-mainnet.helius-rpc.com/?api-key=\(apiKey)" :
            "wss://api.mainnet-beta.solana.com"
        
        print("🚀 Initialized SolanaBlockchainMonitor with \(useHelius ? "Helius" : "Public") RPC")
    }
    
    // MARK: - Connection Management
    
    func startMonitoring() {
        guard connectionStatus != .connected && connectionStatus != .connecting else { return }
        
        connectionStatus = .connecting
        print("🔗 Starting Solana blockchain monitoring...")
        
        if useHelius && !apiKey.isEmpty {
            startHeliusWebSocket()
            startHeliusPolling()
        } else {
            startDirectRPCMonitoring()
        }
    }
    
    func stopMonitoring() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionStatus = .disconnected
        print("🛑 Stopped Solana blockchain monitoring")
    }
    
    // MARK: - Helius Integration
    
    private func startHeliusWebSocket() {
        guard let url = URL(string: rpcEndpoint) else {
            connectionStatus = .error("Invalid RPC endpoint")
            return
        }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Subscribe to program logs for token creation
        subscribeToProgram(SolanaPrograms.splToken, method: "programSubscribe")
        
        // Subscribe to Raydium pool creation
        subscribeToProgram(SolanaPrograms.raydiumAMM, method: "programSubscribe")
        subscribeToProgram(SolanaPrograms.raydiumCPMM, method: "programSubscribe")
        
        // Subscribe to Orca pool creation
        subscribeToProgram(SolanaPrograms.orcaWhirlpool, method: "programSubscribe")
        
        // Subscribe to Pump.fun program
        subscribeToProgram(SolanaPrograms.pumpFunProgram, method: "programSubscribe")
        
        receiveMessages()
        connectionStatus = .connected
        print("✅ Connected to Helius WebSocket for real-time monitoring")
    }
    
    private func startHeliusPolling() {
        // Poll Helius API for new tokens every 30 seconds
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.pollHeliusNewTokens()
                    await self?.pollQuickNodeNewPools()
                }
            }
            .store(in: &cancellables)
    }
    
    private func pollHeliusNewTokens() async {
        guard !apiKey.isEmpty else { return }
        
        let url = URL(string: "https://api.helius.xyz/v0/tokens/recently-created?api-key=\(apiKey)&limit=50")!
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let tokens = try JSONDecoder().decode([HeliusTokenResponse].self, from: data)
            
            await MainActor.run {
                for token in tokens {
                    let event = TokenCreationEvent(
                        mint: token.mint,
                        authority: token.updateAuthority ?? "",
                        decimals: token.decimals ?? 9,
                        supply: token.supply,
                        freezeAuthority: nil,
                        slot: 0,
                        blockTime: Date(),
                        signature: ""
                    )
                    
                    if !self.newTokenEvents.contains(where: { $0.mint == token.mint }) {
                        self.newTokenEvents.append(event)
                        print("🪙 New token detected via Helius: \(token.symbol ?? "Unknown") (\(token.mint.prefix(8))...)")
                        
                        // Convert to TokenCreation and post notification
                        self.postTokenCreationNotification(from: token)
                    }
                }
                
                // Keep only last 100 events
                if self.newTokenEvents.count > 100 {
                    self.newTokenEvents = Array(self.newTokenEvents.suffix(100))
                }
            }
        } catch {
            print("❌ Error polling Helius new tokens: \(error)")
        }
    }
    
    private func pollQuickNodeNewPools() async {
        // This would require QuickNode Metis add-on subscription
        // Placeholder for QuickNode integration
        guard !apiKey.isEmpty else { return }
        
        // Example endpoint: https://api.quicknode.com/addon/metis/new-pools
        // Implementation would depend on specific QuickNode setup
        print("📊 QuickNode polling placeholder - requires Metis add-on subscription")
    }
    
    // MARK: - Direct RPC Monitoring
    
    private func startDirectRPCMonitoring() {
        guard let url = URL(string: "wss://api.mainnet-beta.solana.com") else {
            connectionStatus = .error("Invalid RPC endpoint")
            return
        }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Subscribe to logs for token programs
        subscribeToLogs(filter: ["mentions": [SolanaPrograms.splToken]])
        subscribeToLogs(filter: ["mentions": [SolanaPrograms.raydiumAMM]])
        subscribeToLogs(filter: ["mentions": [SolanaPrograms.orcaWhirlpool]])
        
        receiveMessages()
        connectionStatus = .connected
        print("✅ Connected to Solana RPC for direct monitoring")
    }
    
    // MARK: - WebSocket Message Handling
    
    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleWebSocketMessage(message)
                self?.receiveMessages() // Continue listening
            case .failure(let error):
                print("❌ WebSocket error: \(error)")
                self?.connectionStatus = .error(error.localizedDescription)
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseBlockchainEvent(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseBlockchainEvent(text)
            }
        @unknown default:
            break
        }
    }
    
    private func parseBlockchainEvent(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let method = json["method"] as? String {
                    switch method {
                    case "programNotification":
                        handleProgramNotification(json)
                    case "logsNotification":
                        handleLogsNotification(json)
                    default:
                        break
                    }
                }
            }
        } catch {
            print("❌ Error parsing blockchain event: \(error)")
        }
    }
    
    private func handleProgramNotification(_ json: [String: Any]) {
        guard let params = json["params"] as? [String: Any],
              let result = params["result"] as? [String: Any],
              let account = result["account"] as? [String: Any],
              let data = account["data"] as? [Any],
              let programId = result["pubkey"] as? String else { return }
        
        print("📡 Program notification for: \(programId)")
        
        // Parse based on program type
        switch programId {
        case SolanaPrograms.splToken:
            handleTokenProgramNotification(data, pubkey: programId)
        case SolanaPrograms.raydiumAMM, SolanaPrograms.raydiumCPMM:
            handleRaydiumNotification(data, pubkey: programId)
        case SolanaPrograms.orcaWhirlpool:
            handleOrcaNotification(data, pubkey: programId)
        case SolanaPrograms.pumpFunProgram:
            handlePumpFunNotification(data, pubkey: programId)
        default:
            break
        }
    }
    
    private func handleLogsNotification(_ json: [String: Any]) {
        guard let params = json["params"] as? [String: Any],
              let result = params["result"] as? [String: Any],
              let signature = result["signature"] as? String,
              let logs = result["logs"] as? [String] else { return }
        
        print("📜 Logs notification for signature: \(signature.prefix(8))...")
        
        // Analyze logs for token creation patterns
        for log in logs {
            if log.contains("InitializeMint") {
                print("🪙 Token creation detected in logs: \(signature.prefix(8))...")
                // Could fetch full transaction details here
            } else if log.contains("InitializePool") || log.contains("Initialize") {
                print("🏊 Pool creation detected in logs: \(signature.prefix(8))...")
                // Could fetch full transaction details here
            }
        }
    }
    
    // MARK: - Program-Specific Handlers
    
    private func handleTokenProgramNotification(_ data: [Any], pubkey: String) {
        print("🪙 SPL Token program notification")
        // Parse token mint initialization data
        // This would require detailed SPL token program data parsing
    }
    
    private func handleRaydiumNotification(_ data: [Any], pubkey: String) {
        print("🌊 Raydium pool notification")
        // Parse Raydium pool creation data
        // This would require detailed Raydium AMM program data parsing
    }
    
    private func handleOrcaNotification(_ data: [Any], pubkey: String) {
        print("🐋 Orca whirlpool notification")
        // Parse Orca pool creation data
    }
    
    private func handlePumpFunNotification(_ data: [Any], pubkey: String) {
        print("🚀 Pump.fun program notification")
        // Parse Pump.fun token launch data
    }
    
    // MARK: - Subscription Methods
    
    private func subscribeToProgram(_ programId: String, method: String) {
        let subscription = [
            "jsonrpc": "2.0",
            "id": Int.random(in: 1...1000),
            "method": method,
            "params": [
                programId,
                [
                    "encoding": "base64",
                    "commitment": "confirmed"
                ]
            ]
        ] as [String: Any]
        
        sendWebSocketMessage(subscription)
    }
    
    private func subscribeToLogs(filter: [String: Any]) {
        let subscription = [
            "jsonrpc": "2.0",
            "id": Int.random(in: 1...1000),
            "method": "logsSubscribe",
            "params": [
                filter,
                [
                    "commitment": "confirmed"
                ]
            ]
        ] as [String: Any]
        
        sendWebSocketMessage(subscription)
    }
    
    private func sendWebSocketMessage(_ message: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            let string = String(data: data, encoding: .utf8) ?? ""
            let wsMessage = URLSessionWebSocketTask.Message.string(string)
            
            webSocketTask?.send(wsMessage) { error in
                if let error = error {
                    print("❌ Error sending WebSocket message: \(error)")
                }
            }
        } catch {
            print("❌ Error serializing WebSocket message: \(error)")
        }
    }
    
    // MARK: - Token Metadata Enhancement
    
    func enrichTokenMetadata(mint: String) async -> TokenMetadata? {
        guard !apiKey.isEmpty else { return nil }
        
        let url = URL(string: "https://api.helius.xyz/v0/tokens/\(mint)?api-key=\(apiKey)")!
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let token = try JSONDecoder().decode(HeliusTokenResponse.self, from: data)
            
            return TokenMetadata(
                mint: token.mint,
                name: token.name,
                symbol: token.symbol,
                description: token.description,
                image: token.imageUri,
                externalUrl: nil,
                creators: token.creators?.map { creator in
                    TokenCreator(
                        address: creator.address,
                        verified: creator.verified,
                        share: creator.share
                    )
                }
            )
        } catch {
            print("❌ Error enriching token metadata: \(error)")
            return nil
        }
    }
    
    // MARK: - Notification Integration
    
    private func postTokenCreationNotification(from heliusToken: HeliusTokenResponse) {
        let tokenCreation = TokenCreation(
            mint: heliusToken.mint,
            name: heliusToken.name ?? "Unknown",
            symbol: heliusToken.symbol ?? "UNKNOWN",
            description: heliusToken.description,
            image: heliusToken.imageUri,
            createdTimestamp: Date().timeIntervalSince1970 * 1000,
            creator: heliusToken.updateAuthority,
            totalSupply: Double(heliusToken.supply ?? "0"),
            initialLiquidity: nil,
            raydiumPool: nil,
            complete: false,
            metadataUri: heliusToken.metadataUri, // Add metadata URI from Helius response
            webSocketSocialLinks: nil, // No WebSocket social links from Helius
            // Pump.fun specific fields - nil for Helius detected tokens
            marketCapSol: nil,
            solAmount: nil,
            initialBuy: nil,
            vSolInBondingCurve: nil,
            vTokensInBondingCurve: nil
        )
        
        print("🔔 Posting blockchain-detected token: \(tokenCreation.symbol)")
        
        NotificationCenter.default.post(
            name: NSNotification.Name("NewTokenCreated"),
            object: tokenCreation
        )
    }
    
    // MARK: - Risk Analysis
    
    func analyzeTokenRisk(mint: String) async -> Double {
        // Implement comprehensive risk analysis
        var riskScore: Double = 50.0 // Base score
        
        // Check token metadata quality
        if let metadata = await enrichTokenMetadata(mint: mint) {
            if metadata.name == nil || metadata.symbol == nil {
                riskScore += 20
            }
            
            if metadata.description?.count ?? 0 < 10 {
                riskScore += 15
            }
            
            if metadata.creators?.isEmpty == true {
                riskScore += 10
            }
        }
        
        // Additional risk factors could include:
        // - Initial holder distribution
        // - Creator reputation
        // - Social media presence
        // - Code verification status
        
        return min(100, max(0, riskScore))
    }
}

// MARK: - Extensions

extension SolanaBlockchainMonitor {
    func getConnectionStatusText() -> String {
        switch connectionStatus {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    func getMonitoringStats() -> (tokens: Int, pools: Int) {
        return (newTokenEvents.count, newPoolEvents.count)
    }
}