//
//  Models.swift
//  CSAI1
//
//  Defines coin-related models, but *does not* declare ChatMessage or Conversation
//  to avoid duplications with AIChatViewModel.swift or Conversation.swift.
//

import Foundation

// MARK: - Coin Models

/// Represents a coin as returned by the CoinGecko API.
struct CoinGeckoCoin: Identifiable, Codable {
    let id: String
    let symbol: String
    let name: String?
    let image: String?
    let current_price: Double?
    
    let market_cap: Double?
    let market_cap_rank: Int?
    let total_volume: Double?
    let high_24h: Double?
    let low_24h: Double?
    let price_change_24h: Double?
    let price_change_percentage_24h: Double?
    
    let fully_diluted_valuation: Double?
    let circulating_supply: Double?
    let total_supply: Double?
    let ath: Double?
    let ath_change_percentage: Double?
    let ath_date: String?
    let atl: Double?
    let atl_change_percentage: Double?
    let atl_date: String?
    let last_updated: String?
    
    // For trending endpoint
    let coin_id: Int?
    let thumb: String?
    let small: String?
    let large: String?
    let slug: String?
}

/// Represents the response from a trending coins endpoint.
struct TrendingResponse: Codable {
    let coins: [TrendingCoinItem]
}

/// Wraps a `CoinGeckoCoin` within a "trending item" response.
struct TrendingCoinItem: Codable {
    let item: CoinGeckoCoin
}
