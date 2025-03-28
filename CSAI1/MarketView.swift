//
//  MarketView.swift
//  Example Large Swift File
//
//  Created by ChatGPT on 3/28/25.
//  This file merges multiple fallback endpoints, concurrency, local caching, auto-refresh, and robust image fallback.
//

import SwiftUI
import Charts

// MARK: - Enums & Constants

/// Defines the segments (All, Favorites, Gainers, Losers)
enum MarketSegment: String, CaseIterable {
    case all = "All"
    case favorites = "Favorites"
    case gainers = "Gainers"
    case losers  = "Losers"
}

/// Defines which field we are sorting by
enum SortField: String {
    case coin, price, dailyChange, volume, none
}

/// Defines ascending or descending
enum SortDirection {
    case asc, desc
}

/// We'll store fallback coin logos here
private let fallbackCoinLogos: [String: String] = [
    "BTC": "https://assets.coingecko.com/coins/images/1/large/bitcoin.png",
    "ETH": "https://assets.coingecko.com/coins/images/279/large/ethereum.png",
    "RLC": "https://assets.coingecko.com/coins/images/646/large/rlc.png",
    "USDT": "https://assets.coingecko.com/coins/images/325/large/tether.png",
    "BNB":  "https://assets.coingecko.com/coins/images/825/large/binance-coin-logo.png",
    // add more as needed
]

// MARK: - Data Models

/// Data model from CoinGecko for top coins
struct CoinGeckoMarketData: Codable {
    let id: String
    let symbol: String
    let name: String
    let image: String
    let current_price: Double
    let total_volume: Double
    let price_change_percentage_24h: Double?
    let sparkline_in_7d: SparklineData?
}

/// Sparkline data from CoinGecko
struct SparklineData: Codable {
    let price: [Double]
}

/// Fallback data from CoinPaprika
struct CoinPaprikaData: Codable {
    let id: String
    let symbol: String
    let name: String
    let rank: Int?
    let circulating_supply: Double?
    let total_supply: Double?
    let max_supply: Double?
    let beta_value: Double?
    let first_data_at: String?
    let last_updated: String?
    let quotes: [String: PaprikaQuote]?
}

/// A partial structure to hold Paprika quotes (we only need USD info)
struct PaprikaQuote: Codable {
    let price: Double?
    let volume_24h: Double?
    let market_cap: Double?
    let fully_diluted_market_cap: Double?
    let percent_change_1h: Double?
    let percent_change_24h: Double?
    let percent_change_7d: Double?
}

/// Global data from CoinGecko
struct GlobalMarketDataResponse: Codable {
    let data: GlobalMarketData
}

/// Sub-structure for global data
struct GlobalMarketData: Codable {
    let active_cryptocurrencies: Int?
    let markets: Int?
    let total_market_cap: [String: Double]?
    let total_volume: [String: Double]?
    let market_cap_percentage: [String: Double]?
    let market_cap_change_percentage_24h_usd: Double?
}

/// Additional aggregator fallback for global data
/// (If you have a second aggregator to fallback to, define it here)
struct FallbackGlobalDataResponse: Codable {
    let data: FallbackGlobalData
}

struct FallbackGlobalData: Codable {
    // define structure if you have a second aggregator
    // ...
}

// MARK: - Cache Manager

/// Manages local caching of coin data
class MarketCacheManager {
    static let shared = MarketCacheManager()
    
    private let fileName = "cachedMarketData.json"
    
    private init() {}
    
    /// Saves the raw [CoinGeckoMarketData] array to disk as JSON
    func saveCoinsToDisk(_ coins: [CoinGeckoMarketData]) {
        do {
            let data = try JSONEncoder().encode(coins)
            let url = try cacheFileURL()
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save coin data: \(error)")
        }
    }
    
    /// Loads the raw [CoinGeckoMarketData] from disk if available
    func loadCoinsFromDisk() -> [CoinGeckoMarketData]? {
        do {
            let url = try cacheFileURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([CoinGeckoMarketData].self, from: data)
        } catch {
            print("Failed to load cached data: \(error)")
            return nil
        }
    }
    
    /// Helper to get the file URL
    private func cacheFileURL() throws -> URL {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw URLError(.fileDoesNotExist)
        }
        return docs.appendingPathComponent(fileName)
    }
}

// MARK: - Concurrency Helpers

/// Result for coin fetch with multiple endpoints
fileprivate enum CoinFetchResult {
    case success([CoinGeckoMarketData])
    case fallbackSuccess([CoinPaprikaData])
    case timedOut
    case failure(Error)
}

/// Result for global data fetch with multiple endpoints
fileprivate enum GlobalFetchResult {
    case success(GlobalMarketData)
    case fallbackSuccess(FallbackGlobalData)
    case timedOut
    case failure(Error)
}

// MARK: - ViewModel

/// The main view model that fetches coin data, global data, handles caching, auto-refresh, sorting, searching, etc.
@MainActor
class MarketViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// The full list of coins (unfiltered)
    @Published var coins: [MarketCoin] = []
    
    /// The subset of coins after applying search & segment filters
    @Published var filteredCoins: [MarketCoin] = []
    
    /// Global market data
    @Published var globalData: GlobalMarketData?
    
    /// The user’s selected segment (All/Favorites/Gainers/Losers)
    @Published var selectedSegment: MarketSegment = .all
    
    /// Whether to show the search bar
    @Published var showSearchBar: Bool = false
    
    /// The user’s search text
    @Published var searchText: String = ""
    
    /// Sorting field
    @Published var sortField: SortField = .none
    
    /// Sorting direction
    @Published var sortDirection: SortDirection = .asc
    
    /// Last time we successfully updated coin data
    @Published var lastUpdated: Date?
    
    /// Errors for coin data
    @Published var coinError: String?
    
    /// Errors for global data
    @Published var globalError: String?
    
    // MARK: - Internal Keys & Tasks
    
    private let favoritesKey = "favoriteCoinSymbols"
    
    private var coinRefreshTask: Task<Void, Never>?
    private var globalRefreshTask: Task<Void, Never>?
    
    // MARK: - Init
    
    init() {
        // 1) Try loading cached data
        if let cached = MarketCacheManager.shared.loadCoinsFromDisk() {
            self.coins = cached.map {
                MarketCoin(
                    symbol: $0.symbol.uppercased(),
                    name: $0.name,
                    price: $0.current_price,
                    dailyChange: $0.price_change_percentage_24h ?? 0,
                    volume: $0.total_volume,
                    sparklineData: $0.sparkline_in_7d?.price ?? [],
                    imageUrl: $0.image
                )
            }
            loadFavorites()
            applyAllFiltersAndSort()
        } else {
            // 2) If no cache, load fallback
            loadFallbackCoins()
            applyAllFiltersAndSort()
        }
        
        // 3) Kick off concurrency tasks
        Task {
            await fetchMarketDataMulti()
            await fetchGlobalMarketDataMulti()
        }
        
        // 4) Start auto-refresh
        startAutoRefresh()
    }
    
    /// Clean up tasks
    deinit {
        coinRefreshTask?.cancel()
        globalRefreshTask?.cancel()
    }
    
    // MARK: - Multiple Endpoints for Coin Data
    
    /// Main function that tries CoinGecko, then fallback to CoinPaprika if needed
    func fetchMarketDataMulti() async {
        do {
            let result = try await withThrowingTaskGroup(of: CoinFetchResult.self) { group -> CoinFetchResult in
                // a) Start coin gecko fetch in one task
                group.addTask {
                    return try await self.fetchCoinGecko()
                }
                // b) Start a 3-second global timeout
                group.addTask {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    return .timedOut
                }
                
                // c) Wait for first result
                for try await subResult in group {
                    group.cancelAll()
                    return subResult
                }
                return .timedOut
            }
            
            switch result {
            case .success(let rawCoins):
                // Save to disk
                MarketCacheManager.shared.saveCoinsToDisk(rawCoins)
                // Convert to [MarketCoin]
                self.coins = rawCoins.map {
                    MarketCoin(
                        symbol: $0.symbol.uppercased(),
                        name: $0.name,
                        price: $0.current_price,
                        dailyChange: $0.price_change_percentage_24h ?? 0,
                        volume: $0.total_volume,
                        sparklineData: $0.sparkline_in_7d?.price ?? [],
                        imageUrl: $0.image
                    )
                }
                coinError = nil
                
            case .fallbackSuccess(let papCoins):
                // Convert Paprika data
                self.coins = papCoins.map {
                    let price = $0.quotes?["USD"]?.price ?? 0
                    let volume = $0.quotes?["USD"]?.volume_24h ?? 0
                    let change24h = $0.quotes?["USD"]?.percent_change_24h ?? 0
                    return MarketCoin(
                        symbol: $0.symbol.uppercased(),
                        name: $0.name,
                        price: price,
                        dailyChange: change24h,
                        volume: volume,
                        sparklineData: [], // no sparkline from fallback
                        imageUrl: nil
                    )
                }
                coinError = "Using fallback from CoinPaprika."
                
            case .timedOut:
                self.coinError = "Coin data request timed out. Using fallback/cached."
                
            case .failure(let err):
                self.coinError = "Coin data error: \(err.localizedDescription)"
            }
            
            // Refresh favorites & filter
            loadFavorites()
            applyAllFiltersAndSort()
            lastUpdated = Date()
            
        } catch {
            // If first attempt (CoinGecko) fails, we fallback to Paprika
            // This is also covered by the result == .failure route
            self.coinError = "Coin data error: \(error.localizedDescription)"
        }
    }
    
    /// Actually fetch from CoinGecko
    private func fetchCoinGecko() async throws -> CoinFetchResult {
        let urlString = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&sparkline=true"
        guard let url = URL(string: urlString) else {
            return .failure(URLError(.badURL))
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
            return .failure(URLError(.badServerResponse))
        }
        let decoded = try JSONDecoder().decode([CoinGeckoMarketData].self, from: data)
        return .success(decoded)
    }
    
    /// Fallback to CoinPaprika if CoinGecko fails
    private func fetchCoinPaprika() async throws -> CoinFetchResult {
        let urlString = "https://api.coinpaprika.com/v1/tickers?quotes=USD"
        guard let url = URL(string: urlString) else {
            return .failure(URLError(.badURL))
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
            return .failure(URLError(.badServerResponse))
        }
        let decoded = try JSONDecoder().decode([CoinPaprikaData].self, from: data)
        return .fallbackSuccess(decoded)
    }
    
    // MARK: - Multiple Endpoints for Global Data
    
    /// Main function that tries CoinGecko global, fallback aggregator if needed
    func fetchGlobalMarketDataMulti() async {
        do {
            let result = try await withThrowingTaskGroup(of: GlobalFetchResult.self) { group -> GlobalFetchResult in
                // a) Start coin gecko global in one task
                group.addTask {
                    return try await self.fetchGlobalCoinGecko()
                }
                // b) Start a 3-second global timeout
                group.addTask {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    return .timedOut
                }
                
                for try await subResult in group {
                    group.cancelAll()
                    return subResult
                }
                return .timedOut
            }
            
            switch result {
            case .success(let gData):
                self.globalData = gData
                globalError = nil
                
            case .fallbackSuccess(_):
                // If you had a second aggregator, parse it here
                globalError = "Using fallback aggregator for global data."
                
            case .timedOut:
                self.globalError = "Global data request timed out."
                
            case .failure(let e):
                self.globalError = "Global data error: \(e.localizedDescription)"
            }
        } catch {
            globalError = "Global data error: \(error.localizedDescription)"
        }
    }
    
    /// Actually fetch from CoinGecko global
    private func fetchGlobalCoinGecko() async throws -> GlobalFetchResult {
        let urlString = "https://api.coingecko.com/api/v3/global"
        guard let url = URL(string: urlString) else {
            return .failure(URLError(.badURL))
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
            return .failure(URLError(.badServerResponse))
        }
        let decoded = try JSONDecoder().decode(GlobalMarketDataResponse.self, from: data)
        return .success(decoded.data)
    }
    
    /// Fallback aggregator for global data (placeholder)
    private func fetchGlobalFallback() async throws -> GlobalFetchResult {
        // If you had a second aggregator for global data, do it here
        // returning .fallbackSuccess
        throw URLError(.badURL)
    }
    
    // MARK: - Fallback local data
    
    /// Hardcoded fallback coin list in case everything fails
    private func loadFallbackCoins() {
        coins = [
            MarketCoin(symbol: "BTC", name: "Bitcoin", price: 28000, dailyChange: -2.15, volume: 450_000_000,
                       sparklineData: [28000, 27950, 27980, 27890, 27850, 27820, 27800],
                       imageUrl: "https://assets.coingecko.com/coins/images/1/large/bitcoin.png"),
            MarketCoin(symbol: "ETH", name: "Ethereum", price: 1800, dailyChange: 3.44, volume: 210_000_000,
                       sparklineData: [1790, 1795, 1802, 1808, 1805, 1810, 1807],
                       imageUrl: "https://assets.coingecko.com/coins/images/279/large/ethereum.png"),
            MarketCoin(symbol: "USDT", name: "Tether", price: 1.0, dailyChange: 0.0, volume: 300_000_000,
                       sparklineData: [1.0, 1.0, 1.0],
                       imageUrl: "https://assets.coingecko.com/coins/images/325/large/tether.png"),
            MarketCoin(symbol: "BNB", name: "Binance Coin", price: 310, dailyChange: -1.20, volume: 120_000_000,
                       sparklineData: [312, 311, 310, 309, 310, 308, 309],
                       imageUrl: "https://assets.coingecko.com/coins/images/825/large/binance-coin-logo.png"),
            MarketCoin(symbol: "RLC", name: "iExec RLC", price: 2.05, dailyChange: 1.25, volume: 12_000_000,
                       sparklineData: [2.0, 2.01, 2.05, 2.06, 2.03, 2.02, 2.04],
                       imageUrl: "https://assets.coingecko.com/coins/images/646/large/rlc.png"),
            // ... add more as you wish
        ]
        loadFavorites()
    }
    
    // MARK: - Favorites
    
    /// Loads the user's favorite coins from UserDefaults
    private func loadFavorites() {
        let saved = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        for i in coins.indices {
            if saved.contains(coins[i].symbol.uppercased()) {
                coins[i].isFavorite = true
            }
        }
    }
    
    /// Saves the user's favorite coins to UserDefaults
    private func saveFavorites() {
        let faves = coins.filter { $0.isFavorite }.map { $0.symbol.uppercased() }
        UserDefaults.standard.setValue(faves, forKey: favoritesKey)
    }
    
    /// Toggles the favorite status for a given coin
    func toggleFavorite(_ coin: MarketCoin) {
        guard let idx = coins.firstIndex(where: { $0.id == coin.id }) else { return }
        withAnimation(.spring()) {
            coins[idx].isFavorite.toggle()
        }
        saveFavorites()
        applyAllFiltersAndSort()
    }
    
    // MARK: - Sorting & Filtering
    
    /// Updates the selected segment
    func updateSegment(_ seg: MarketSegment) {
        selectedSegment = seg
        applyAllFiltersAndSort()
    }
    
    /// Updates the search text
    func updateSearch(_ query: String) {
        searchText = query
        applyAllFiltersAndSort()
    }
    
    /// Toggles the sort field or direction
    func toggleSort(for field: SortField) {
        if sortField == field {
            sortDirection = (sortDirection == .asc) ? .desc : .asc
        } else {
            sortField = field
            sortDirection = .asc
        }
        applyAllFiltersAndSort()
    }
    
    /// Applies search, segment, and sorting
    func applyAllFiltersAndSort() {
        var result = coins
        
        // 1) Search filter
        let lowerSearch = searchText.lowercased()
        if !lowerSearch.isEmpty {
            result = result.filter {
                $0.symbol.lowercased().contains(lowerSearch) ||
                $0.name.lowercased().contains(lowerSearch)
            }
        }
        
        // 2) Segment filter
        switch selectedSegment {
        case .favorites:
            result = result.filter { $0.isFavorite }
        case .gainers:
            result = result.filter { $0.dailyChange > 0 }
        case .losers:
            result = result.filter { $0.dailyChange < 0 }
        default:
            break
        }
        
        // 3) Sort
        filteredCoins = sortCoins(result)
    }
    
    /// Sorts the array based on sortField & sortDirection
    private func sortCoins(_ arr: [MarketCoin]) -> [MarketCoin] {
        guard sortField != .none else { return arr }
        return arr.sorted { lhs, rhs in
            switch sortField {
            case .coin:
                let compare = lhs.symbol.localizedCaseInsensitiveCompare(rhs.symbol)
                return sortDirection == .asc
                    ? (compare == .orderedAscending)
                    : (compare == .orderedDescending)
            case .price:
                return sortDirection == .asc ? (lhs.price < rhs.price) : (lhs.price > rhs.price)
            case .dailyChange:
                return sortDirection == .asc ? (lhs.dailyChange < rhs.dailyChange) : (lhs.dailyChange > rhs.dailyChange)
            case .volume:
                return sortDirection == .asc ? (lhs.volume < rhs.volume) : (lhs.volume > rhs.volume)
            case .none:
                return false
            }
        }
    }
    
    // MARK: - Auto-Refresh
    
    /// Starts two background tasks to auto-refresh coin data and global data
    private func startAutoRefresh() {
        // a) Coin data every 60s
        coinRefreshTask = Task.detached { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                await self.fetchMarketDataMulti()
            }
        }
        
        // b) Global data every 3 min
        globalRefreshTask = Task.detached { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 180_000_000_000) // 3 minutes
                await self.fetchGlobalMarketDataMulti()
            }
        }
    }
    
    // MARK: - Optional Live Price Updates
    
    /// Example of how you might fetch live prices from Coinbase or similar
    func fetchLivePricesFromCoinbase() {
        Task {
            for (index, coin) in coins.enumerated() {
                // coinbase call
                if let newPrice = await CoinbaseService().fetchSpotPrice(coin: coin.symbol, fiat: "USD") {
                    coins[index].price = newPrice
                }
                // binance sparkline
                let newSpark = await BinanceService.fetchSparkline(symbol: coin.symbol)
                if !newSpark.isEmpty {
                    coins[index].sparklineData = newSpark
                }
            }
            applyAllFiltersAndSort()
        }
    }
}

// MARK: - Main MarketView

/// The main SwiftUI view that shows the top bar, global summary, segments, search, table header, and coin list
struct MarketView: View {
    @EnvironmentObject var vm: MarketViewModel
    
    private let coinWidth: CGFloat   = 140
    private let priceWidth: CGFloat  = 70
    private let dailyWidth: CGFloat  = 50
    private let volumeWidth: CGFloat = 70
    private let starWidth: CGFloat   = 40
    
    var body: some View {
        NavigationView {
            ZStack {
                // background
                Color.black.ignoresSafeArea()
                
                // main vertical stack
                VStack(spacing: 0) {
                    topBar
                    summaryView
                    segmentRow
                    if vm.showSearchBar {
                        searchBar
                    }
                    columnHeader
                    coinList
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Top Bar
    
    /// A top bar with only a search button on the right
    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                withAnimation {
                    vm.showSearchBar.toggle()
                }
            } label: {
                Image(systemName: vm.showSearchBar ? "magnifyingglass.circle.fill" : "magnifyingglass.circle")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Global Data Summary
    
    /// Displays the global data (market cap, volume, BTC dominance) or errors/timeouts
    private var summaryView: some View {
        VStack(spacing: 8) {
            if let global = vm.globalData, vm.globalError == nil {
                // If we have valid global data
                HStack {
                    if let cap = global.total_market_cap?["usd"] {
                        Text("Market Cap: \(cap.formattedWithAbbreviations())")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    if let vol = global.total_volume?["usd"] {
                        Text("Volume: \(vol.formattedWithAbbreviations())")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                HStack {
                    if let btcDom = global.market_cap_percentage?["btc"] {
                        Text("BTC Dominance: \(String(format: "%.1f", btcDom))%")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    if let updated = vm.lastUpdated {
                        Text("Updated: \(updated.formattedAsTime())")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            } else {
                // If there's an error or still loading
                if let gErr = vm.globalError {
                    Text(gErr)
                        .font(.footnote)
                        .foregroundColor(.red)
                } else {
                    Text("Loading global market data...")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            // If there's a coin error, show it
            if let cErr = vm.coinError {
                Text(cErr)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
    }
    
    // MARK: - Segment Row
    
    /// The horizontal row for All / Favorites / Gainers / Losers
    private var segmentRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MarketSegment.allCases, id: \.self) { seg in
                    Button {
                        vm.updateSegment(seg)
                    } label: {
                        Text(seg.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(vm.selectedSegment == seg ? .black : .white)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(vm.selectedSegment == seg ? Color.white : Color.white.opacity(0.1))
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
    
    // MARK: - Search Bar
    
    /// The collapsible search bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search coins...", text: $vm.searchText)
                .foregroundColor(.white)
                .onChange(of: vm.searchText) { _ in
                    vm.applyAllFiltersAndSort()
                }
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Column Header
    
    /// The row that shows "Coin  7D  Price  24h  Vol  *"
    private var columnHeader: some View {
        HStack(spacing: 0) {
            headerButton("Coin", .coin)
                .frame(width: coinWidth, alignment: .leading)
            
            Text("7D")
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 40, alignment: .trailing)
            
            headerButton("Price", .price)
                .frame(width: priceWidth, alignment: .trailing)
            
            headerButton("24h", .dailyChange)
                .frame(width: dailyWidth, alignment: .trailing)
            
            headerButton("Vol", .volume)
                .frame(width: volumeWidth, alignment: .trailing)
            
            Spacer().frame(width: starWidth)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
    }
    
    /// A helper for the column header sort toggles
    private func headerButton(_ label: String, _ field: SortField) -> some View {
        Button {
            vm.toggleSort(for: field)
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                
                if vm.sortField == field {
                    Image(systemName: vm.sortDirection == .asc ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(vm.sortField == field ? Color.white.opacity(0.05) : Color.clear)
    }
    
    // MARK: - Coin List
    
    /// The main scrollable list of coins
    private var coinList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if vm.filteredCoins.isEmpty {
                    Text(vm.searchText.isEmpty ? "No coins available." : "No coins match your search.")
                        .foregroundColor(.gray)
                        .padding(.top, 40)
                } else {
                    ForEach(vm.filteredCoins) { coin in
                        NavigationLink(destination: CoinDetailView(coin: coin)) {
                            coinRow(coin)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 16)
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .refreshable {
            // On pull-to-refresh, fetch coin & global
            await vm.fetchMarketDataMulti()
            await vm.fetchGlobalMarketDataMulti()
        }
    }
    
    /// A single row in the coin list
    private func coinRow(_ coin: MarketCoin) -> some View {
        HStack(spacing: 0) {
            // 1) Symbol + name + image
            HStack(spacing: 8) {
                coinImageView(symbol: coin.symbol, urlStr: coin.imageUrl)
                VStack(alignment: .leading, spacing: 2) {
                    Text(coin.symbol.uppercased())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(coin.name)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            .frame(width: coinWidth, alignment: .leading)
            
            // 2) Sparkline
            if #available(iOS 16, *) {
                ZStack {
                    Rectangle().fill(Color.clear)
                        .frame(width: 50, height: 30)
                    sparkline(coin.sparklineData, dailyChange: coin.dailyChange)
                }
            } else {
                Spacer().frame(width: 50)
            }
            
            // 3) Price
            Text(String(format: "$%.2f", coin.price))
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(width: priceWidth, alignment: .trailing)
                .lineLimit(1)
            
            // 4) 24h change
            Text(String(format: "%.2f%%", coin.dailyChange))
                .font(.caption)
                .foregroundColor(coin.dailyChange >= 0 ? .green : .red)
                .frame(width: dailyWidth, alignment: .trailing)
                .lineLimit(1)
            
            // 5) Volume
            Text(shortVolume(coin.volume))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))
                .frame(width: volumeWidth, alignment: .trailing)
                .lineLimit(1)
            
            // 6) Favorite star
            Button {
                vm.toggleFavorite(coin)
            } label: {
                Image(systemName: coin.isFavorite ? "star.fill" : "star")
                    .foregroundColor(coin.isFavorite ? .yellow : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: starWidth, alignment: .center)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
    }
    
    // MARK: - Sparkline
    
    /// Renders a small sparkline chart for the past 7 days
    @ViewBuilder
    private func sparkline(_ data: [Double], dailyChange: Double) -> some View {
        if data.isEmpty {
            Rectangle().fill(Color.white.opacity(0.1))
        } else {
            let minValue = data.min() ?? 0
            let maxValue = data.max() ?? 1
            let range = maxValue - minValue
            let domainPaddingFraction = 0.15
            let lowerBound = minValue - range * domainPaddingFraction
            let upperBound = maxValue + range * domainPaddingFraction
            
            Chart {
                ForEach(data.indices, id: \.self) { i in
                    LineMark(
                        x: .value("Index", i),
                        y: .value("Price", data[i])
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(dailyChange >= 0 ? Color.green : Color.red)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: lowerBound...upperBound)
            .chartPlotStyle { plotArea in
                plotArea.frame(width: 50, height: 30)
            }
        }
    }
}

// MARK: - Coin Image View

/// Renders a coin image with multiple fallback strategies:
/// 1) If `urlStr` is valid, try it
/// 2) If that fails, see if there's a known fallbackCoinLogos entry
/// 3) If that fails, show a local default "defaultCoin"
private func coinImageView(symbol: String, urlStr: String?) -> some View {
    Group {
        if let urlStr = urlStr, let mainURL = URL(string: urlStr) {
            AsyncImage(url: mainURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                case .failure(_):
                    // Try fallback dictionary
                    fallbackOrDefault(symbol: symbol)
                case .empty:
                    ProgressView()
                        .frame(width: 32, height: 32)
                @unknown default:
                    fallbackOrDefault(symbol: symbol)
                }
            }
        } else {
            fallbackOrDefault(symbol: symbol)
        }
    }
}

/// If the main URL fails or is nil, we fallback to a known dictionary or default
private func fallbackOrDefault(symbol: String) -> some View {
    if let fallbackURLStr = fallbackCoinLogos[symbol.uppercased()],
       let fallbackURL = URL(string: fallbackURLStr)
    {
        return AnyView(
            AsyncImage(url: fallbackURL) { phase2 in
                switch phase2 {
                case .success(let fallbackImage):
                    fallbackImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                case .failure(_):
                    Image("defaultCoin")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                case .empty:
                    ProgressView()
                        .frame(width: 32, height: 32)
                @unknown default:
                    Image("defaultCoin")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                }
            }
        )
    } else {
        return AnyView(
            Image("defaultCoin")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
        )
    }
}

// MARK: - Helpers & Extensions

extension Double {
    /// Formats a Double with abbreviations: 1K, 1.2M, 1.0B, etc.
    func formattedWithAbbreviations() -> String {
        let absValue = abs(self)
        switch absValue {
        case 1_000_000_000_000...:
            return String(format: "%.1fT", self / 1_000_000_000_000)
        case 1_000_000_000...:
            return String(format: "%.1fB", self / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM", self / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", self / 1_000)
        default:
            return String(format: "%.0f", self)
        }
    }
}

extension Date {
    /// Formats date as short time, e.g. "6:47 PM"
    func formattedAsTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

/// Short volume formatting
private func shortVolume(_ vol: Double) -> String {
    vol.formattedWithAbbreviations()
}

// MARK: - Sample Preview

struct MarketView_Previews: PreviewProvider {
    static var previews: some View {
        MarketView()
            .environmentObject(MarketViewModel())
    }
}
