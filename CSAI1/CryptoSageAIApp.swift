//
//  CryptoSageAIApp.swift
//  CSAI1
//
//  Created by DM on 3/27/25.
//


//
//  CryptoSageAIApp.swift
//  CSAI1
//
//  Created by DM on 3/16/25.
//
//  AppMain.swift
//  CRYPTOSAI
//
//  Single app entry point, with shared AppState.
//
import SwiftUI

@main
struct CryptoSageAIApp: App {
    // Existing app-wide state
    @StateObject private var appState = AppState()
    // Existing "market" or new watchlist VM
    @StateObject private var watchlistVM = WatchlistViewModel()

    var body: some Scene {
        WindowGroup {
            ContentManagerView()
                .environmentObject(appState)
                .environmentObject(watchlistVM)
                .preferredColorScheme(appState.isDarkMode ? .dark : .light)
        }
    }
}

// MARK: - Example AppState
class AppState: ObservableObject {
    @Published var selectedTab: CustomTab = .home
    @Published var isDarkMode: Bool = true
}

// MARK: - Example WatchlistViewModel
/// Rename or adapt if you already have a MarketViewModel
class WatchlistViewModel: ObservableObject {
    @Published var coins: [WatchlistCoin] = []
    
    init() {
        // Start with sample or fetch real data
        self.coins = [
            WatchlistCoin(id: "btc", symbol: "BTC", price: 28000, isFavorite: true),
            WatchlistCoin(id: "eth", symbol: "ETH", price: 1800,  isFavorite: true),
            // etc...
        ]
    }
}

// MARK: - Example Model
struct WatchlistCoin: Identifiable {
    let id: String
    let symbol: String
    var price: Double
    var isFavorite: Bool
}
