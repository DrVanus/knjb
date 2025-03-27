//
//  MarketViewModel.swift
//  CSAI1
//
//  Created by DM on 3/27/25.
//


import SwiftUI

class MarketViewModel: ObservableObject {
    @Published var coins: [MarketCoin] = []
    @Published var filteredCoins: [MarketCoin] = []
    
    // UI state
    @Published var selectedSegment: MarketSegment = .all
    @Published var showSearchBar: Bool = false
    @Published var searchText: String = ""
    
    // Sorting
    @Published var sortField: SortField = .none
    @Published var sortDirection: SortDirection = .asc
    
    // Favorites
    private let favoritesKey = "favoriteCoinSymbols"
    
    init() {
        loadFallbackCoins()
        applyAllFiltersAndSort()
        fetchLivePricesFromCoinbase()
    }
    
    // Fallback coins, loadFavorites(), saveFavorites(), toggleFavorite(), etc.
    // ... (rest of your MarketViewModel code) ...
}