//
//  CSAI1App.swift
//  CSAI1
//
//  Created by DM on 3/27/25.
//

import SwiftUI

struct CSAI1App: App {
    @StateObject var marketVM = MarketViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(marketVM)
        }
    }
}
