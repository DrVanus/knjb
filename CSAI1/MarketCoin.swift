// MarketCoin.swift

import Foundation

struct MarketCoin: Identifiable, Codable {
    // We'll store a UUID as the id for Identifiable
    let id: UUID
    
    let symbol: String
    let name: String
    
    // price is var so we can update it after fetching from Coinbase
    var price: Double
    
    // dailyChange is var in case you want to update it
    var dailyChange: Double
    
    // volume is var in case you want to update it
    var volume: Double
    
    // isFavorite is var so you can toggle it
    var isFavorite: Bool
    
    // sparklineData is var so you can update it after fetching
    var sparklineData: [Double]
    
    let imageUrl: String?
    
    // Custom init to match how MarketView passes arguments
    init(
        symbol: String,
        name: String,
        price: Double,
        dailyChange: Double,
        volume: Double,
        sparklineData: [Double],
        imageUrl: String?,
        isFavorite: Bool = false
    ) {
        self.id = UUID()
        self.symbol = symbol
        self.name = name
        self.price = price
        self.dailyChange = dailyChange
        self.volume = volume
        self.sparklineData = sparklineData
        self.imageUrl = imageUrl
        self.isFavorite = isFavorite
    }
}
