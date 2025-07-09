//
//  IPFSService.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/26/25.
//

import Foundation
import Combine

// MARK: - IPFS Token Metadata Models
struct IPFSTokenMetadata: Codable {
    let name: String?
    let symbol: String?
    let description: String?
    let image: String?
    let external_url: String?
    let attributes: [TokenAttribute]?
    let properties: TokenProperties?
    let seller_fee_basis_points: Int?
    let collection: TokenCollection?
    
    // Direct social media fields that can appear at root level
    let twitter: String?
    let telegram: String?
    let discord: String?
    let website: String?
    let showName: Bool?
    let createdOn: String?
}

struct TokenAttribute: Codable {
    let trait_type: String?
    let value: String?
}

struct TokenProperties: Codable {
    let files: [TokenFile]?
    let category: String?
    let creators: [IPFSTokenCreator]?
}

struct TokenFile: Codable {
    let uri: String?
    let type: String?
}

struct IPFSTokenCreator: Codable {
    let address: String?
    let share: Int?
}

struct TokenCollection: Codable {
    let name: String?
    let family: String?
}

// MARK: - Enhanced Token Info
struct EnhancedTokenInfo: Codable {
    let baseInfo: TokenInfo
    let ipfsMetadata: IPFSTokenMetadata?
    let resolvedImageURL: String?
    let socialLinks: [String]?
    let verified: Bool
}

// MARK: - IPFS Service
class IPFSService: ObservableObject {
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    
    // IPFS Gateway URLs (fallback order) - Removed problematic cloudflare-ipfs.com
    private let ipfsGateways = [
        "https://ipfs.io/ipfs/",
        "https://gateway.ipfs.io/ipfs/",
        "https://dweb.link/ipfs/",
        "https://gateway.pinata.cloud/ipfs/"
    ]
    
    private var metadataCache: [String: IPFSTokenMetadata] = [:]
    private var imageCache: [String: String] = [:]
    
    init() {
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    // MARK: - Public Methods
    
    /// Enhance token info with IPFS metadata (optimized for real-time processing with background threading)
    func enhanceTokenInfo(_ tokenInfo: TokenInfo, metadataUri: String? = nil, webSocketSocialLinks: [String]? = nil) async -> EnhancedTokenInfo {
        print("🔍 Enhancing token info for: \(tokenInfo.symbol) on background thread")
        
        // Ensure this runs on a background thread to not block the main thread
        return await withCheckedContinuation { continuation in
            Task.detached(priority: .background) {
                let result = await self.performEnhancement(tokenInfo, metadataUri: metadataUri, webSocketSocialLinks: webSocketSocialLinks)
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Internal enhancement method that runs on background thread
    private func performEnhancement(_ tokenInfo: TokenInfo, metadataUri: String? = nil, webSocketSocialLinks: [String]? = nil) async -> EnhancedTokenInfo {
        
        print("🔍 IPFS Enhancement received WebSocket social links: \(webSocketSocialLinks ?? [])")
        
        var ipfsMetadata: IPFSTokenMetadata?
        var resolvedImageURL: String?
        var socialLinks: [String] = []
        var verified = false
        
        // Priority 1: Try metadataUri if provided (often contains full token metadata)
        if let metadataUri = metadataUri, !metadataUri.isEmpty {
            if let ipfsHash = extractIPFSHash(from: metadataUri) {
                print("📋 Found IPFS hash in metadataUri: \(ipfsHash.prefix(8))...")
                ipfsMetadata = await fetchIPFSMetadataFast(hash: ipfsHash)
                
                if let metadata = ipfsMetadata {
                    print("   ✅ Successfully fetched metadata from metadataUri")
                }
            } else if metadataUri.hasPrefix("http") {
                print("📋 Found HTTP metadata URL: \(metadataUri.prefix(50))...")
                ipfsMetadata = await fetchHTTPMetadata(url: metadataUri)
                
                if let metadata = ipfsMetadata {
                    print("   ✅ Successfully fetched metadata from HTTP URL")
                }
            }
        }
        
        // Priority 2: Try to get metadata from the token's logoURI if no metadata found yet
        if ipfsMetadata == nil, let logoURI = tokenInfo.logoURI {
            if let ipfsHash = extractIPFSHash(from: logoURI) {
                print("📎 Found IPFS hash in logoURI: \(ipfsHash.prefix(8))...")
                ipfsMetadata = await fetchIPFSMetadataFast(hash: ipfsHash)
                
                if let metadata = ipfsMetadata {
                    print("   ✅ Successfully fetched metadata from logoURI")
                }
            } else if logoURI.hasPrefix("http") {
                // Direct HTTP image URL - validate quickly
                resolvedImageURL = logoURI
                print("   ✅ Using direct image URL for \(tokenInfo.symbol)")
            }
        }
        
        // Process metadata if found with parallel execution
        if let metadata = ipfsMetadata {
            // Process image and social links in parallel with timeout protection
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    resolvedImageURL = await self.resolveImageURLFast(from: metadata.image)
                }
                group.addTask {
                    socialLinks = await self.extractSocialLinks(from: metadata)
                }
                group.addTask {
                    verified = self.isVerifiedToken(metadata: metadata)
                }
                
                // Wait for all tasks with a timeout
                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: 3_000_000_000) // 3 second timeout
                }
                
                await group.waitForAll()
                timeoutTask.cancel()
            }
            
            print("   ✅ IPFS enhancement completed for \(tokenInfo.symbol) (background thread)")
        } else {
            print("   ⚠️ No IPFS metadata found for \(tokenInfo.symbol) (background thread)")
        }
        
        // Add WebSocket social links if available (for both IPFS and non-IPFS cases)
        if let wsLinks = webSocketSocialLinks, !wsLinks.isEmpty {
            let initialCount = socialLinks.count
            socialLinks.append(contentsOf: wsLinks)
            print("   🌐 Added \(wsLinks.count) WebSocket social links to existing \(initialCount) IPFS links (total: \(socialLinks.count))")
        }
        
        return EnhancedTokenInfo(
            baseInfo: tokenInfo,
            ipfsMetadata: ipfsMetadata,
            resolvedImageURL: resolvedImageURL,
            socialLinks: socialLinks.isEmpty ? nil : socialLinks,
            verified: verified
        )
    }
    
    /// Fetch metadata from HTTP URL (for non-IPFS metadata URLs)
    func fetchHTTPMetadata(url: String) async -> IPFSTokenMetadata? {
        do {
            guard let httpUrl = URL(string: url) else { return nil }
            
            var request = URLRequest(url: httpUrl)
            request.timeoutInterval = 5.0 // Fast timeout
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                return try decoder.decode(IPFSTokenMetadata.self, from: data)
            }
        } catch {
            print("❌ Failed to fetch HTTP metadata from \(url): \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Fast metadata fetching for real-time token processing (shorter timeouts)
    func fetchIPFSMetadataFast(hash: String) async -> IPFSTokenMetadata? {
        // Check cache first
        if let cached = metadataCache[hash] {
            print("📋 Using cached metadata for hash: \(hash.prefix(8))...")
            return cached
        }
        
        print("⚡ Fast-fetching IPFS metadata for hash: \(hash.prefix(8))...")
        
        // Try only the fastest gateways with shorter timeout - Removed problematic cloudflare-ipfs.com
        let fastGateways = ["https://ipfs.io/ipfs/", "https://gateway.ipfs.io/ipfs/"]
        
        // Use TaskGroup for parallel requests to speed up with better threading
        return await withTaskGroup(of: IPFSTokenMetadata?.self) { group in
            for gateway in fastGateways {
                group.addTask {
                    await self.fetchFromGateway(hash: hash, gateway: gateway, timeout: 3.0)
                }
            }
            
            // Return the first successful result with timeout protection
            var resultCount = 0
            for await result in group {
                resultCount += 1
                if let metadata = result {
                    // Cancel remaining tasks to improve performance
                    group.cancelAll()
                    self.metadataCache[hash] = metadata
                    print("✅ Fast-fetched metadata successfully from gateway \(resultCount)")
                    return metadata
                }
                
                // If all gateways failed, exit early
                if resultCount >= fastGateways.count {
                    break
                }
            }
            
            print("❌ Fast-fetch failed for hash: \(hash.prefix(8))... (tried \(resultCount) gateways)")
            return nil
        }
    }
    
    /// Fetch metadata from IPFS hash
    func fetchIPFSMetadata(hash: String) async -> IPFSTokenMetadata? {
        // Check cache first
        if let cached = metadataCache[hash] {
            print("📋 Using cached metadata for hash: \(hash.prefix(8))...")
            return cached
        }
        
        print("🌐 Fetching IPFS metadata for hash: \(hash.prefix(8))...")
        
        // Try each gateway until one works
        for gateway in ipfsGateways {
            let urlString = "\(gateway)\(hash)"
            
            do {
                guard let url = URL(string: urlString) else { continue }
                
                var request = URLRequest(url: url)
                request.timeoutInterval = 10.0 // Fast timeout for IPFS
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                
                let (data, response) = try await session.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    
                    let metadata = try decoder.decode(IPFSTokenMetadata.self, from: data)
                    
                    // Cache the result
                    metadataCache[hash] = metadata
                    
                    print("✅ Successfully fetched metadata from \(gateway)")
                    print("   Name: \(metadata.name ?? "Unknown")")
                    print("   Description: \(metadata.description?.prefix(50) ?? "None")...")
                    
                    return metadata
                }
            } catch {
                print("⚠️ Failed to fetch from \(gateway): \(error.localizedDescription)")
                continue
            }
        }
        
        print("❌ Failed to fetch metadata from all IPFS gateways for hash: \(hash.prefix(8))...")
        return nil
    }
    
    /// Resolve image URL from IPFS or direct URL
    func resolveImageURL(from imageString: String?) async -> String? {
        guard let imageString = imageString else { return nil }
        
        // Check cache first
        if let cached = imageCache[imageString] {
            return cached
        }
        
        var resolvedURL: String?
        
        if let ipfsHash = extractIPFSHash(from: imageString) {
            // Try to resolve IPFS image URL
            for gateway in ipfsGateways {
                let testURL = "\(gateway)\(ipfsHash)"
                if await isImageURLValid(testURL) {
                    resolvedURL = testURL
                    break
                }
            }
        } else if imageString.hasPrefix("http") {
            // Direct HTTP URL
            if await isImageURLValid(imageString) {
                resolvedURL = imageString
            }
        }
        
        // Cache the result
        if let resolved = resolvedURL {
            imageCache[imageString] = resolved
            print("🖼️ Resolved image URL: \(resolved)")
        }
        
        return resolvedURL
    }
    
    /// Fast image URL resolution for real-time processing
    func resolveImageURLFast(from imageString: String?) async -> String? {
        guard let imageString = imageString else { return nil }
        
        // Check cache first
        if let cached = imageCache[imageString] {
            return cached
        }
        
        if let ipfsHash = extractIPFSHash(from: imageString) {
            // Try only the fastest gateway for images
            let fastImageURL = "https://ipfs.io/ipfs/\(ipfsHash)"
            imageCache[imageString] = fastImageURL
            return fastImageURL
        } else if imageString.hasPrefix("http") {
            // Direct HTTP URL - assume it's valid for speed
            imageCache[imageString] = imageString
            return imageString
        }
        
        return nil
    }
    
    /// Fetch from a specific gateway with timeout and better error handling
    private func fetchFromGateway(hash: String, gateway: String, timeout: TimeInterval) async -> IPFSTokenMetadata? {
        let urlString = "\(gateway)\(hash)"
        
        do {
            guard let url = URL(string: urlString) else { 
                print("❌ Invalid URL: \(urlString)")
                return nil 
            }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = timeout
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
            
            // Add timeout wrapper to prevent hanging
            let result = try await withThrowingTaskGroup(of: IPFSTokenMetadata?.self) { group in
                group.addTask {
                    let (data, response) = try await self.session.data(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 {
                            return try self.decoder.decode(IPFSTokenMetadata.self, from: data)
                        } else {
                            print("⚠️ HTTP \(httpResponse.statusCode) from \(gateway)")
                        }
                    }
                    return nil
                }
                
                // Timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    return nil
                }
                
                // Return first result (success or timeout)
                for try await result in group {
                    group.cancelAll()
                    return result
                }
                return nil
            }
            
            return result
        } catch {
            if error.localizedDescription.contains("could not be found") {
                print("❌ Network error for \(gateway): \(error.localizedDescription)")
            }
            // Silent fail for other errors to reduce console spam
        }
        
        return nil
    }
    
    // MARK: - Private Helper Methods
    
    private func extractIPFSHash(from urlString: String) -> String? {
        // Handle various IPFS URL formats:
        // ipfs://QmHash
        // https://ipfs.io/ipfs/QmHash
        // QmHash (raw hash)
        
        if urlString.hasPrefix("ipfs://") {
            return String(urlString.dropFirst(7))
        }
        
        if urlString.contains("/ipfs/") {
            let components = urlString.components(separatedBy: "/ipfs/")
            return components.last
        }
        
        // Check if it's a raw IPFS hash (starts with Qm or ba)
        if urlString.hasPrefix("Qm") || urlString.hasPrefix("ba") {
            return urlString
        }
        
        return nil
    }
    
    private func tryCommonMetadataPatterns(for tokenInfo: TokenInfo) async -> IPFSTokenMetadata? {
        // Some tokens store metadata at predictable IPFS locations
        // This is speculative - try common patterns
        
        let commonPatterns = [
            // Try variations based on token address
            generateHashFromAddress(tokenInfo.address),
            // Try common metadata hashes for popular tokens
        ].compactMap { $0 }
        
        for pattern in commonPatterns {
            if let metadata = await fetchIPFSMetadata(hash: pattern) {
                return metadata
            }
        }
        
        return nil
    }
    
    private func generateHashFromAddress(_ address: String) -> String? {
        // This is a placeholder - in reality, you'd need to know how the token
        // stores its metadata hash. Some tokens store it on-chain.
        return nil
    }
    
    private func extractSocialLinks(from metadata: IPFSTokenMetadata) -> [String] {
        var links: [String] = []
        
        print("🔍 Extracting social links from IPFS metadata...")
        
        // Check direct social media fields at root level
        if let twitter = metadata.twitter, !twitter.isEmpty {
            links.append(twitter)
            print("   🐦 Found direct twitter field: \(twitter)")
        }
        
        if let telegram = metadata.telegram, !telegram.isEmpty {
            links.append(telegram)
            print("   📱 Found direct telegram field: \(telegram)")
        }
        
        if let discord = metadata.discord, !discord.isEmpty {
            links.append(discord)
            print("   💬 Found direct discord field: \(discord)")
        }
        
        if let website = metadata.website, !website.isEmpty {
            links.append(website)
            print("   🌐 Found direct website field: \(website)")
        }
        
        // Check external_url field
        if let externalURL = metadata.external_url, !externalURL.isEmpty {
            links.append(externalURL)
            print("   📎 Found external_url: \(externalURL)")
        }
        
        // Look for social links in description
        if let description = metadata.description {
            let patterns = [
                "https://twitter.com/[A-Za-z0-9_]+",
                "https://x.com/[A-Za-z0-9_]+", 
                "https://t.me/[A-Za-z0-9_]+",
                "https://discord.gg/[A-Za-z0-9_]+",
                "https://[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
            ]
            
            for pattern in patterns {
                let regex = try? NSRegularExpression(pattern: pattern)
                let matches = regex?.matches(in: description, range: NSRange(description.startIndex..., in: description))
                
                for match in matches ?? [] {
                    if let range = Range(match.range, in: description) {
                        let url = String(description[range])
                        links.append(url)
                        print("   📝 Found in description: \(url)")
                    }
                }
            }
        }
        
        print("🔍 Total IPFS social links found: \(links.count)")
        return Array(Set(links)) // Remove duplicates
    }
    
    private func isVerifiedToken(metadata: IPFSTokenMetadata) -> Bool {
        // Simple verification heuristics
        guard let description = metadata.description else { return false }
        
        let verificationIndicators = [
            description.count > 50, // Decent description length
            metadata.external_url != nil, // Has official website
            metadata.collection != nil, // Part of a collection
            metadata.attributes != nil // Has attributes/properties
        ]
        
        return verificationIndicators.filter { $0 }.count >= 2
    }
    
    private func isImageURLValid(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD" // Just check headers, don't download
            request.timeoutInterval = 5.0
            
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200 && 
                       httpResponse.mimeType?.hasPrefix("image/") == true
            }
        } catch {
            return false
        }
        
        return false
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        metadataCache.removeAll()
        imageCache.removeAll()
        print("🗑️ IPFS cache cleared")
    }
    
    func getCacheStats() -> (metadataCount: Int, imageCount: Int) {
        return (metadataCache.count, imageCache.count)
    }
}

// MARK: - IPFS Integration Extensions

extension TradingPair {
    func withEnhancedMetadata(_ enhancedInfo: EnhancedTokenInfo) -> TradingPair {
        var updatedBaseToken = self.baseToken
        
        // Update with enhanced metadata
        if let metadata = enhancedInfo.ipfsMetadata {
            if let name = metadata.name, !name.isEmpty {
                updatedBaseToken = TokenInfo(
                    address: updatedBaseToken.address,
                    symbol: updatedBaseToken.symbol,
                    name: name, // Use IPFS name if available
                    decimals: updatedBaseToken.decimals,
                    logoURI: enhancedInfo.resolvedImageURL ?? updatedBaseToken.logoURI
                )
            }
        }
        
        return TradingPair(
            id: self.id,
            address: self.address,
            baseToken: updatedBaseToken,
            quoteToken: self.quoteToken,
            dex: self.dex,
            liquidity: self.liquidity,
            volume24h: self.volume24h,
            priceChange24h: self.priceChange24h,
            marketCap: self.marketCap,
            createdAt: self.createdAt,
            migrationStatus: self.migrationStatus,
            riskScore: enhancedInfo.verified ? max(0, self.riskScore - 15) : self.riskScore, // Lower risk for verified tokens
            holderCount: self.holderCount,
            topHolderPercent: self.topHolderPercent,
            enhancedMetadata: enhancedInfo // Store the enhanced metadata
        )
    }
}