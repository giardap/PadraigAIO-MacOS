//
//  WalletManager.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/24/25.
//

import Foundation
import Security
import Combine
import SwiftData
import JavaScriptCore

// MARK: - Keychain Helper
class KeychainHelper {
    static func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }
    
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}

// MARK: - Solana Wallet Manager
class WalletManager: ObservableObject {
    @Published var wallets: [Wallet] = []
    @Published var balances: [String: Double] = [:]
    @Published var isLoading = false
    @Published var lastError: String?
    
    var modelContext: ModelContext
    private var solanaJS: SolanaJSBridge
    private var transactionSender: TransactionSenderManager
    private var cancellables = Set<AnyCancellable>()
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.solanaJS = SolanaJSBridge()
        self.transactionSender = TransactionSenderManager()
        
        loadWallets()
        
        // Update balances every 30 seconds
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateAllBalances()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Solana Integration
    
    // MARK: - Wallet Operations
    func createWallet(name: String) async -> Bool {
        isLoading = true
        lastError = nil
        
        do {
            // Create wallet using PumpPortal API
            guard let pumpWalletData = await createPumpPortalWallet() else {
                throw WalletError.pumpPortalCreationFailed
            }
            
            // Create wallet object with API key
            let wallet = Wallet(name: name, publicKey: pumpWalletData.publicKey, apiKey: pumpWalletData.apiKey)
            
            // Save private key to keychain
            let privateKeyData = pumpWalletData.privateKey.data(using: .utf8)!
            let keychainKey = "wallet_\(wallet.id.uuidString)"
            
            guard KeychainHelper.save(key: keychainKey, data: privateKeyData) else {
                throw WalletError.keychainSaveFailed
            }
            
            // Save wallet to database
            modelContext.insert(wallet)
            try modelContext.save()
            
            // Update local array
            await MainActor.run {
                wallets.append(wallet)
                isLoading = false
            }
            
            // Update balance
            await updateBalance(for: wallet)
            
            return true
            
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                isLoading = false
            }
            return false
        }
    }
    
    // MARK: - PumpPortal Integration
    private func createPumpPortalWallet() async -> PumpPortalWalletResponse? {
        guard let url = URL(string: "https://pumpportal.fun/api/create-wallet") else {
            print("Invalid PumpPortal URL")
            return nil
        }
        
        do {
            print("Making request to PumpPortal API...")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("PumpPortal API response status: \(httpResponse.statusCode)")
            }
            
            print("Received data: \(String(data: data, encoding: .utf8) ?? "Unable to convert to string")")
            
            let walletResponse = try JSONDecoder().decode(PumpPortalWalletResponse.self, from: data)
            print("Successfully decoded wallet response")
            return walletResponse
        } catch let decodingError as DecodingError {
            print("JSON Decoding error: \(decodingError)")
            return nil
        } catch {
            print("Error creating PumpPortal wallet: \(error)")
            return nil
        }
    }
    
    func importWallet(name: String, privateKey: String) async -> Bool {
        isLoading = true
        lastError = nil
        
        do {
            // Validate private key format (basic validation)
            guard privateKey.count > 50 else {
                throw WalletError.invalidPrivateKey
            }
            
            // For now, generate a mock public key
            // In real implementation, derive public key from private key
            let publicKey = "mock_public_key_\(UUID().uuidString.prefix(10))"
            
            let wallet = Wallet(name: name, publicKey: publicKey)
            
            // Save private key to keychain
            let privateKeyData = privateKey.data(using: .utf8)!
            let keychainKey = "wallet_\(wallet.id.uuidString)"
            
            guard KeychainHelper.save(key: keychainKey, data: privateKeyData) else {
                throw WalletError.keychainSaveFailed
            }
            
            // Save to database
            modelContext.insert(wallet)
            try modelContext.save()
            
            await MainActor.run {
                wallets.append(wallet)
                isLoading = false
            }
            
            await updateBalance(for: wallet)
            
            return true
            
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                isLoading = false
            }
            return false
        }
    }
    
    func deleteWallet(_ wallet: Wallet) {
        // Delete private key from keychain
        let keychainKey = "wallet_\(wallet.id.uuidString)"
        _ = KeychainHelper.delete(key: keychainKey)
        
        // Delete from database
        modelContext.delete(wallet)
        try? modelContext.save()
        
        // Remove from local array
        wallets.removeAll { $0.id == wallet.id }
        balances.removeValue(forKey: wallet.publicKey)
    }
    
    func exportPrivateKey(for wallet: Wallet) -> String? {
        let keychainKey = "wallet_\(wallet.id.uuidString)"
        guard let data = KeychainHelper.load(key: keychainKey),
              let privateKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        return privateKey
    }
    
    // MARK: - Balance Management
    func updateBalance(for wallet: Wallet) async {
        // Use Solana JS Bridge to get balance
        let balance = await solanaJS.getBalance(publicKey: wallet.publicKey) ?? 0.0
        
        await MainActor.run {
            balances[wallet.publicKey] = balance
            wallet.balance = balance
            wallet.lastUpdated = Date()
            try? modelContext.save()
        }
    }
    
    func updateAllBalances() {
        Task {
            for wallet in wallets where wallet.isActive {
                await updateBalance(for: wallet)
            }
        }
    }
    
    // MARK: - Transaction Methods
    func sendTransaction(from wallet: Wallet, to address: String, amount: Double) async -> TransactionResult {
        guard let privateKey = exportPrivateKey(for: wallet) else {
            return TransactionResult(success: false, signature: nil, price: nil, gasUsed: nil, error: "Could not retrieve private key")
        }
        
        // For now, return a mock successful transaction
        // In real implementation, would use Solana JS bridge to send SOL transfer
        let success = Double.random(in: 0...1) > 0.1 // 90% success rate
        
        if success {
            await updateBalance(for: wallet)
            return TransactionResult(
                success: true,
                signature: "mock_\(UUID().uuidString)",
                price: amount,
                gasUsed: 0.000005,
                error: nil
            )
        } else {
            return TransactionResult(
                success: false,
                signature: nil,
                price: nil,
                gasUsed: 0.000005,
                error: "Transaction failed"
            )
        }
    }
    
    // MARK: - Trading Methods
    func buyToken(mint: String, amount: Double, slippage: Double, wallet: Wallet, pool: String = "pump") async -> TransactionResult {
        guard let privateKey = exportPrivateKey(for: wallet) else {
            return TransactionResult(success: false, signature: nil, price: nil, gasUsed: nil, error: "Could not retrieve private key")
        }
        
        // Use new TransactionSender for enhanced provider support
        let transactionParams = TransactionParameters(
            action: "buy",
            mint: mint,
            amount: amount,
            slippage: slippage,
            walletAddress: wallet.publicKey,
            priorityFee: nil, // Use default
            jitoTip: nil      // Use default minimum
        )
        
        let transactionResult = await transactionSender.executeTransaction(transactionParams)
        
        // Convert TransactionSender result to WalletManager result format
        let result = TransactionResult(
            success: transactionResult.success,
            signature: transactionResult.signature,
            price: nil, // Not provided by TransactionSender
            gasUsed: nil, // Not provided by TransactionSender  
            error: transactionResult.error
        )
        
        if result.success {
            await updateBalance(for: wallet)
        }
        
        return result
    }
    
    func sellToken(mint: String, amount: Double, slippage: Double, wallet: Wallet, pool: String = "pump") async -> TransactionResult {
        guard let privateKey = exportPrivateKey(for: wallet) else {
            return TransactionResult(success: false, signature: nil, price: nil, gasUsed: nil, error: "Could not retrieve private key")
        }
        
        // Use new TransactionSender for enhanced provider support
        let transactionParams = TransactionParameters(
            action: "sell",
            mint: mint,
            amount: amount,
            slippage: slippage,
            walletAddress: wallet.publicKey,
            priorityFee: nil, // Use default
            jitoTip: nil      // Use default minimum
        )
        
        let transactionResult = await transactionSender.executeTransaction(transactionParams)
        
        // Convert TransactionSender result to WalletManager result format
        let result = TransactionResult(
            success: transactionResult.success,
            signature: transactionResult.signature,
            price: nil, // Not provided by TransactionSender
            gasUsed: nil, // Not provided by TransactionSender
            error: transactionResult.error
        )
        
        if result.success {
            await updateBalance(for: wallet)
        }
        
        return result
    }
    
    // MARK: - Transaction Provider Configuration
    
    /// Access to transaction sender for provider selection
    var transactionProviderManager: TransactionSenderManager {
        return transactionSender
    }
    
    /// Switch transaction provider (PumpPortal Lightning vs Helius Sender)
    func setTransactionProvider(_ provider: TransactionSenderProvider) {
        transactionSender.switchProvider(to: provider)
    }
    
    // MARK: - Private Methods
    private func loadWallets() {
        let request = FetchDescriptor<Wallet>()
        do {
            wallets = try modelContext.fetch(request)
        } catch {
            print("Failed to load wallets: \(error)")
        }
    }
}

// MARK: - Supporting Types
enum WalletError: LocalizedError {
    case keypairGenerationFailed
    case keychainSaveFailed
    case invalidPrivateKey
    case walletNotFound
    case pumpPortalCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .keypairGenerationFailed:
            return "Failed to generate keypair"
        case .keychainSaveFailed:
            return "Failed to save to keychain"
        case .invalidPrivateKey:
            return "Invalid private key format"
        case .walletNotFound:
            return "Wallet not found"
        case .pumpPortalCreationFailed:
            return "Failed to create wallet with PumpPortal API"
        }
    }
}

// MARK: - PumpPortal API Response
struct PumpPortalWalletResponse: Codable {
    let publicKey: String
    let privateKey: String
    let apiKey: String
    
    enum CodingKeys: String, CodingKey {
        case publicKey = "walletPublicKey"
        case privateKey = "privateKey"
        case apiKey = "apiKey"
    }
}

struct TransactionResult {
    let success: Bool
    let signature: String?
    let price: Double?
    let gasUsed: Double?
    let error: String?
}