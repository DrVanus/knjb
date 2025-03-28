import SwiftUI

// MARK: - Temporary Extensions for Demo
// In production, remove these simulated values and update your model accordingly.
extension WatchlistCoin {
    // Simulated percentage change values.
    // In a real app, these would come from live API data.
    var change1h: Double { Double.random(in: -5...5) }
    var change24h: Double { Double.random(in: -10...10) }
}

// MARK: - AnimatedPriceText
/// Displays the coin’s price with a color flash and an arrow icon whenever the price changes.
struct AnimatedPriceText: View {
    let price: Double

    // Store the previous price for comparison.
    @State private var oldPrice: Double = 0.0
    // Current text color (default white).
    @State private var textColor: Color = .white
    // Control whether to show the arrow icon.
    @State private var showArrow: Bool = false
    // The name of the arrow icon (up or down).
    @State private var arrowName: String = ""

    var body: some View {
        HStack(spacing: 2) {
            Text(formatPrice(price))
                .foregroundColor(textColor.opacity(0.7))
                .font(.footnote)
            if showArrow {
                Image(systemName: arrowName)
                    .foregroundColor(textColor)
                    .transition(.opacity)
            }
        }
        .onAppear {
            oldPrice = price
        }
        .onChange(of: price) { oldVal, newVal in
            guard newVal != oldVal else { return }
            if newVal > oldVal {
                textColor = .green
                arrowName = "arrow.up"
            } else {
                textColor = .red
                arrowName = "arrow.down"
            }
            withAnimation(.easeInOut) {
                showArrow = true
            }
            // Revert back after 1 second.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut) {
                    textColor = .white
                    showArrow = false
                }
            }
            oldPrice = newVal
        }
    }

    /// Formats a price value into a currency string.
    private func formatPrice(_ value: Double) -> String {
        guard value > 0 else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if value < 1.0 {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 8
        } else {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        }
        return "$" + (formatter.string(from: NSNumber(value: value)) ?? "0.00")
    }
}

// MARK: - WatchlistSectionView
struct WatchlistSectionView: View {
    // Use our WatchlistViewModel from the environment.
    @EnvironmentObject var watchlistVM: WatchlistViewModel
    // Binding that controls whether the list is in editing mode.
    @Binding var isEditingWatchlist: Bool

    // Local state to toggle "Show More/Show Less"
    @State private var showAll = false
    // Timer that fires every 15 seconds to simulate live updates.
    @State private var refreshTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    // Compute the user's watchlist (favorite coins)
    private var liveWatchlist: [WatchlistCoin] {
        watchlistVM.coins.filter { $0.isFavorite }
    }

    // How many coins to show when collapsed
    private let maxVisible = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section heading
            sectionHeading("Your Watchlist", iconName: "eye")

            if liveWatchlist.isEmpty {
                emptyWatchlistView
            } else {
                // Determine which coins to display
                let coinsToShow = showAll ? liveWatchlist : Array(liveWatchlist.prefix(maxVisible))

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.03))

                    List {
                        ForEach(coinsToShow, id: \.id) { coin in
                            VStack(spacing: 0) {
                                rowContent(for: coin)
                            }
                            .listRowInsets(EdgeInsets()) // Remove default padding
                            .listRowBackground(Color.clear)
                        }
                        .onMove(perform: moveCoinInWatchlist)
                    }
                    .listStyle(.plain)
                    .listRowSpacing(0)
                    .scrollDisabled(true)
                    // Approx. 45 points per row
                    .frame(height: showAll ? CGFloat(liveWatchlist.count) * 45
                                           : CGFloat(maxVisible) * 45)
                    .animation(.easeInOut, value: showAll)
                    .environment(\.editMode, .constant(isEditingWatchlist ? .active : .inactive))
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity)

                if liveWatchlist.count > maxVisible {
                    Button {
                        withAnimation(.spring()) {
                            showAll.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(showAll ? "Show Less" : "Show More")
                                .font(.callout)
                                .foregroundColor(.white)
                            Image(systemName: showAll ? "chevron.up" : "chevron.down")
                                .foregroundColor(.white)
                                .font(.footnote)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .onReceive(refreshTimer) { _ in
            // Simulate live price updates.
            watchlistVM.updatePrices()
        }
    }

    // MARK: - Empty Watchlist View
    private var emptyWatchlistView: some View {
        VStack(spacing: 16) {
            Text("No coins in your watchlist yet.")
                .font(.callout)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Row Content
    private func rowContent(for coin: WatchlistCoin) -> some View {
        HStack(spacing: 8) {
            // Vertical gold gradient bar (optional – you can remove it if you prefer).
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.yellow, Color.orange]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)

            // Coin icon and info.
            coinIconView(for: coin, size: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(coin.symbol.uppercased())
                    .font(.subheadline)
                    .foregroundColor(.white)
                // Animated price with flash and arrow icon.
                AnimatedPriceText(price: coin.price)
            }

            Spacer()

            // Percentage changes for 1H and 24H.
            HStack(spacing: 12) {
                HStack(spacing: 2) {
                    Text("1H:")
                        .foregroundColor(.white.opacity(0.7))
                    Text(String(format: "%+.2f%%", coin.change1h))
                        .foregroundColor(coin.change1h >= 0 ? .green : .red)
                }
                HStack(spacing: 2) {
                    Text("24H:")
                        .foregroundColor(.white.opacity(0.7))
                    Text(String(format: "%+.2f%%", coin.change24h))
                        .foregroundColor(coin.change24h >= 0 ? .green : .red)
                }
            }
            .font(.footnote)
            .animation(.easeInOut, value: coin.change1h)
            .animation(.easeInOut, value: coin.change24h)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.clear)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                if let index = watchlistVM.coins.firstIndex(where: { $0.id == coin.id }) {
                    watchlistVM.coins[index].isFavorite = false
                }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    // MARK: - Reordering (Drag & Drop)
    private func moveCoinInWatchlist(from source: IndexSet, to destination: Int) {
        var favorites = watchlistVM.coins.filter { $0.isFavorite }
        favorites.move(fromOffsets: source, toOffset: destination)
        let nonFavorites = watchlistVM.coins.filter { !$0.isFavorite }
        watchlistVM.coins = nonFavorites + favorites
        withAnimation(.spring()) { }
    }

    // MARK: - Helper: Coin Icon View
    private func coinIconView(for coin: WatchlistCoin, size: CGFloat) -> some View {
        Group {
            if let imageUrl = coin.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure(_):
                        Circle().fill(Color.gray.opacity(0.3))
                            .frame(width: size, height: size)
                    case .empty:
                        ProgressView().frame(width: size, height: size)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Circle().fill(Color.gray.opacity(0.3))
                    .frame(width: size, height: size)
            }
        }
    }

    // MARK: - Helper: Section Heading
    private func sectionHeading(_ text: String, iconName: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let icon = iconName {
                    Image(systemName: icon)
                        .foregroundColor(.yellow)
                }
                Text(text)
                    .font(.title3).bold()
                    .foregroundColor(.white)
            }
            Divider().background(Color.white.opacity(0.15))
        }
    }
}
