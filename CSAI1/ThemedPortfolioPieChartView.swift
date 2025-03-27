//
//  ThemedPortfolioPieChartView.swift
//  CSAI1
//

import SwiftUI
import Charts

/// A donut (pie) chart view that displays each coin’s share of the portfolio
/// based on its current value (quantity * currentPrice).
struct ThemedPortfolioPieChartView: View {
    let holdings: [Holding]
    
    var body: some View {
        if #available(iOS 16.0, *) {
            Chart(holdings, id: \.id) { holding in
                SectorMark(
                    // Use current value to define slice size
                    angle: .value("Value", holding.currentPrice * holding.quantity),
                    innerRadius: .ratio(0.6),
                    outerRadius: .ratio(0.95)
                )
                .foregroundStyle(sliceColor(for: holding.coinSymbol))
            }
            // Hide the default legend
            .chartLegend(.hidden)
        } else {
            Text("Pie chart requires iOS 16+.")
                .foregroundColor(.gray)
        }
    }
    
    private func sliceColor(for symbol: String) -> Color {
        // Customize your slice colors
        let donutSliceColors: [Color] = [
            .green, Color("BrandAccent"), .mint, .blue, .teal, .purple, Color("GoldAccent")
        ]
        let hash = abs(symbol.hashValue)
        return donutSliceColors[hash % donutSliceColors.count]
    }
}

// MARK: - Preview
struct ThemedPortfolioPieChartView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide sample holdings for preview
        ThemedPortfolioPieChartView(holdings: [
            Holding(
                id: UUID(),
                coinName: "Bitcoin",
                coinSymbol: "BTC",
                quantity: 1.5,
                currentPrice: 28000,
                costBasis: 25000,   // added
                imageUrl: nil,
                isFavorite: false,
                dailyChange: 2.5,
                purchaseDate: Date()
            ),
            Holding(
                id: UUID(),
                coinName: "Ethereum",
                coinSymbol: "ETH",
                quantity: 10,
                currentPrice: 1800,
                costBasis: 15000,   // added
                imageUrl: nil,
                isFavorite: false,
                dailyChange: -1.2,
                purchaseDate: Date()
            )
        ])
        .preferredColorScheme(.dark)
    }
}
