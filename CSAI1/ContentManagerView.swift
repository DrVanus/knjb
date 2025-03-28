//
//  ContentManagerView.swift
//  CSAI1
//
//  Created by DM on 3/16/25.
//


//
//  ContentManagerView.swift
//  CRYPTOSAI
//
//  Manages the TabView and switches between tabs.
//
import SwiftUI

struct ContentManagerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $appState.selectedTab) {
                HomeView()
                    .tag(CustomTab.home)
                MarketView()
                    .tag(CustomTab.market)
                TradeView()
                    .tag(CustomTab.trade)
                PortfolioView()
                    .tag(CustomTab.portfolio)
                AITabView()
                    .tag(CustomTab.ai)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            // Smooth transition when switching tabs.
            .animation(.easeInOut, value: appState.selectedTab)

            CustomTabBar(selectedTab: $appState.selectedTab)
                // Add some bottom padding to ensure it's not too close to the edge.
                .padding(.bottom, 8)
        }
        // Make sure the view extends to the bottom edge.
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct ContentManagerView_Previews: PreviewProvider {
    static var previews: some View {
        ContentManagerView()
            .environmentObject(AppState())
    }
}
