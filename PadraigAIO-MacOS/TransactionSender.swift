//
//  TransactionSender.swift
//  PadraigAIO-MacOS
//
//  Enhanced transaction sending service with multiple providers
//  Supports both PumpPortal Lightning and Helius Sender APIs
//

import Foundation
import Combine

// MARK: - Transaction Sender Provider
enum TransactionSenderProvider: String, CaseIterable {
    case pumpPortalLightning = "PumpPortal Lightning"
    case heliusSender = "Helius Sender"
    
    var description: String {
        switch self {
        case .pumpPortalLightning:
            return "Fast execution with built-in transaction creation"
        case .heliusSender:
            return "Ultra-low latency with global routing"
        }
    }
    
    var icon: String {
        switch self {
        case .pumpPortalLightning: return "bolt.fill"
        case .heliusSender: return "network"
        }
    }
}

// MARK: - Transaction Sender Manager
class TransactionSenderManager: ObservableObject {
    @Published var selectedProvider: TransactionSenderProvider = .pumpPortalLightning
    @Published var lastTransactionResult: TransactionSenderResult?
    @Published var isTransactionInProgress = false
    
    private let pumpPortalService = PumpPortalTransactionService()
    private let heliusService = HeliusTransactionService()
    
    // MARK: - Transaction Execution
    
    func executeTransaction(_ params: TransactionParameters) async -> TransactionSenderResult {
        isTransactionInProgress = true
        
        let result: TransactionSenderResult
        
        switch selectedProvider {
        case .pumpPortalLightning:
            result = await pumpPortalService.executeTransaction(params)
        case .heliusSender:
            result = await heliusService.executeTransaction(params)
        }
        
        await MainActor.run {
            self.lastTransactionResult = result
            self.isTransactionInProgress = false
        }
        
        return result
    }
    
    func switchProvider(to provider: TransactionSenderProvider) {
        selectedProvider = provider
        print("🔄 Switched to \(provider.rawValue)")
    }
}

// MARK: - Transaction Parameters
struct TransactionParameters {
    let action: String // "buy" or "sell"
    let mint: String   // Token mint address
    let amount: Double // Amount in SOL
    let slippage: Double // Slippage percentage
    let walletAddress: String
    let priorityFee: Double? // Optional priority fee
    let jitoTip: Double?     // Optional Jito tip for Helius
}

// MARK: - Transaction Sender Result
struct TransactionSenderResult {
    let success: Bool
    let signature: String?
    let error: String?
    let provider: TransactionSenderProvider
    let timestamp: Date
    let latency: TimeInterval
    
    init(success: Bool, signature: String? = nil, error: String? = nil, provider: TransactionSenderProvider, latency: TimeInterval = 0) {
        self.success = success
        self.signature = signature
        self.error = error
        self.provider = provider
        self.timestamp = Date()
        self.latency = latency
    }
}

// MARK: - PumpPortal Transaction Service
class PumpPortalTransactionService {
    private let baseURL = "https://pumpportal.fun/api"
    
    func executeTransaction(_ params: TransactionParameters) async -> TransactionSenderResult {
        let startTime = Date()
        
        do {
            // PumpPortal Lightning API request
            let requestBody: [String: Any] = [
                "action": params.action,
                "mint": params.mint,
                "amount": params.amount,
                "slippage": params.slippage,
                "wallet": params.walletAddress
            ]
            
            let data = try JSONSerialization.data(withJSONObject: requestBody)
            
            var request = URLRequest(url: URL(string: "\(baseURL)/lightning")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            let latency = Date().timeIntervalSince(startTime)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let signature = json["signature"] as? String {
                
                print("✅ PumpPortal Lightning success: \(signature)")
                return TransactionSenderResult(
                    success: true,
                    signature: signature,
                    provider: .pumpPortalLightning,
                    latency: latency
                )
            } else {
                let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
                print("❌ PumpPortal Lightning error: \(errorMessage)")
                return TransactionSenderResult(
                    success: false,
                    error: errorMessage,
                    provider: .pumpPortalLightning,
                    latency: latency
                )
            }
            
        } catch {
            let latency = Date().timeIntervalSince(startTime)
            print("❌ PumpPortal Lightning error: \(error)")
            return TransactionSenderResult(
                success: false,
                error: error.localizedDescription,
                provider: .pumpPortalLightning,
                latency: latency
            )
        }
    }
}

// MARK: - Helius Transaction Service
class HeliusTransactionService {
    // Helius Sender endpoint for ultra-low latency transaction execution
    private let senderEndpoint = "ewr-sender.helius-rpc.com/fast"
    
    // Helius RPC endpoints for standard operations
    private let rpcEndpoints = [
        "mainnet.helius-rpc.com/?api-key=e3b54e60-daee-442f-8b75-1893c5be291f", // Standard mainnet
        "unstaked.helius-rpc.com/?api-key=e3b54e60-daee-442f-8b75-1893c5be291f" // Unstaked for faster execution
    ]
    
    private var selectedEndpoint: String {
        // Use the fast sender endpoint for transaction execution
        return senderEndpoint
    }
    
    func executeTransaction(_ params: TransactionParameters) async -> TransactionSenderResult {
        let startTime = Date()
        
        do {
            // First, we need to create the transaction
            // This would typically involve using a Solana SDK to build the transaction
            let transaction = try await buildTransaction(params)
            
            // Send via Helius Sender
            let result = await sendViaHelius(transaction: transaction, params: params)
            
            let latency = Date().timeIntervalSince(startTime)
            return TransactionSenderResult(
                success: result.success,
                signature: result.signature,
                error: result.error,
                provider: .heliusSender,
                latency: latency
            )
            
        } catch {
            let latency = Date().timeIntervalSince(startTime)
            print("❌ Helius Sender error: \(error)")
            return TransactionSenderResult(
                success: false,
                error: error.localizedDescription,
                provider: .heliusSender,
                latency: latency
            )
        }
    }
    
    private func buildTransaction(_ params: TransactionParameters) async throws -> String {
        // Use Jupiter API to build the swap transaction
        let jupiterTransaction = try await buildJupiterSwapTransaction(params)
        
        // Add priority fees and Jito tips as required by Helius
        let enhancedTransaction = try await addHeliusRequirements(to: jupiterTransaction, params: params)
        
        return enhancedTransaction
    }
    
    private func buildJupiterSwapTransaction(_ params: TransactionParameters) async throws -> String {
        // Step 1: Get quote from Jupiter
        let quote = try await getJupiterQuote(params)
        
        // Step 2: Get swap transaction from Jupiter
        let swapTransaction = try await getJupiterSwapTransaction(quote: quote, params: params)
        
        return swapTransaction
    }
    
    private func getJupiterQuote(_ params: TransactionParameters) async throws -> [String: Any] {
        let jupiterQuoteURL = "https://quote-api.jup.ag/v6/quote"
        
        // Determine input/output mints based on action
        let (inputMint, outputMint, _) = try getSwapMints(params)
        
        // Convert amount to proper decimals (SOL = 9 decimals)
        let amountInDecimals = Int(params.amount * pow(10, 9))
        
        var components = URLComponents(string: jupiterQuoteURL)!
        components.queryItems = [
            URLQueryItem(name: "inputMint", value: inputMint),
            URLQueryItem(name: "outputMint", value: outputMint),
            URLQueryItem(name: "amount", value: String(amountInDecimals)),
            URLQueryItem(name: "slippageBps", value: String(Int(params.slippage * 100))), // Convert % to bps
            URLQueryItem(name: "onlyDirectRoutes", value: "false"),
            URLQueryItem(name: "asLegacyTransaction", value: "false")
        ]
        
        let request = URLRequest(url: components.url!)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TransactionError.networkError("Jupiter quote request failed")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TransactionError.networkError("Invalid Jupiter quote response")
        }
        
        return json
    }
    
    private func getJupiterSwapTransaction(quote: [String: Any], params: TransactionParameters) async throws -> String {
        let jupiterSwapURL = "https://quote-api.jup.ag/v6/swap"
        
        let requestBody: [String: Any] = [
            "quoteResponse": quote,
            "userPublicKey": params.walletAddress,
            "wrapAndUnwrapSol": true,
            "useSharedAccounts": true,
            "feeAccount": "", // Optional fee account
            "trackingAccount": "", // Optional tracking
            "computeUnitPriceMicroLamports": "auto", // Let Jupiter handle priority fees initially
            "prioritizationFeeLamports": "auto"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: URL(string: jupiterSwapURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TransactionError.networkError("Jupiter swap request failed")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let swapTransaction = json["swapTransaction"] as? String else {
            throw TransactionError.networkError("Invalid Jupiter swap response")
        }
        
        return swapTransaction
    }
    
    private func addHeliusRequirements(to transaction: String, params: TransactionParameters) async throws -> String {
        // For Helius Sender, we need to ensure:
        // 1. Priority fees are set (minimum recommended by Helius)
        // 2. Jito tips are added (minimum 0.001 SOL = 1,000,000 lamports)
        
        // For now, return the Jupiter transaction as-is since Jupiter handles priority fees
        // In a production implementation, you would deserialize the transaction,
        // modify priority fees/add Jito tip instruction, then re-serialize
        
        // Validate that we have the minimum Jito tip
        let minimumJitoTip = 0.001 // SOL
        let jitoTip = params.jitoTip ?? minimumJitoTip
        
        if jitoTip < minimumJitoTip {
            print("⚠️ Jito tip (\(jitoTip) SOL) below minimum (\(minimumJitoTip) SOL)")
        }
        
        // Jupiter already includes priority fees, so we can use the transaction directly
        // for basic implementation. Advanced implementation would modify the transaction
        // to add specific Jito tip instructions.
        
        return transaction
    }
    
    private func getSwapMints(_ params: TransactionParameters) throws -> (inputMint: String, outputMint: String, amount: Double) {
        let solMint = "So11111111111111111111111111111111111111112"
        
        switch params.action.lowercased() {
        case "buy":
            // Buy token with SOL
            return (inputMint: solMint, outputMint: params.mint, amount: params.amount)
        case "sell":
            // Sell token for SOL
            return (inputMint: params.mint, outputMint: solMint, amount: params.amount)
        default:
            throw TransactionError.invalidParameters("Invalid action: \(params.action)")
        }
    }
    
    private func sendViaHelius(transaction: String, params: TransactionParameters) async -> (success: Bool, signature: String?, error: String?) {
        do {
            // Helius Sender API request format
            let requestBody: [String: Any] = [
                "jsonrpc": "2.0",
                "method": "sendTransaction",
                "params": [
                    transaction, // Base64 encoded transaction
                    [
                        "skipPreflight": true,    // Mandatory for Helius Sender
                        "maxRetries": 0          // We handle retries ourselves
                    ]
                ],
                "id": Int.random(in: 1...1000)
            ]
            
            let data = try JSONSerialization.data(withJSONObject: requestBody)
            
            var request = URLRequest(url: URL(string: "https://\(selectedEndpoint)")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            // Helius Sender requires Bearer token authorization
            request.setValue("Bearer e3b54e60-daee-442f-8b75-1893c5be291f", forHTTPHeaderField: "Authorization")
            request.httpBody = data
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                
                if let result = json["result"] as? String {
                    print("✅ Helius Sender success: \(result)")
                    return (true, result, nil)
                } else if let error = json["error"] as? [String: Any],
                          let message = error["message"] as? String {
                    print("❌ Helius Sender RPC error: \(message)")
                    return (false, nil, message)
                }
            }
            
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            print("❌ Helius Sender HTTP error: \(errorMessage)")
            return (false, nil, errorMessage)
            
        } catch {
            print("❌ Helius Sender network error: \(error)")
            return (false, nil, error.localizedDescription)
        }
    }
}

// MARK: - Transaction Errors
enum TransactionError: Error {
    case notImplemented(String)
    case invalidParameters(String)
    case networkError(String)
    case insufficientFunds
    case slippageExceeded
    
    var localizedDescription: String {
        switch self {
        case .notImplemented(let message):
            return "Not implemented: \(message)"
        case .invalidParameters(let message):
            return "Invalid parameters: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .insufficientFunds:
            return "Insufficient funds"
        case .slippageExceeded:
            return "Slippage exceeded"
        }
    }
}

// MARK: - Transaction Provider Configuration
struct TransactionProviderConfig {
    let provider: TransactionSenderProvider
    let isEnabled: Bool
    let requiresAPIKey: Bool
    let supportedActions: [String]
    let averageLatency: TimeInterval?
    
    static let configurations: [TransactionProviderConfig] = [
        TransactionProviderConfig(
            provider: .pumpPortalLightning,
            isEnabled: true,
            requiresAPIKey: false,
            supportedActions: ["buy", "sell"],
            averageLatency: 0.5
        ),
        TransactionProviderConfig(
            provider: .heliusSender,
            isEnabled: true, // Now implemented with Jupiter integration
            requiresAPIKey: true,
            supportedActions: ["buy", "sell"],
            averageLatency: 0.2
        )
    ]
}