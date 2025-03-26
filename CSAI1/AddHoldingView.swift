//
//  AddHoldingView.swift
//  CSAI1
//
//  Created by DrVanus on [original date].
//

import SwiftUI

struct AddHoldingView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: PortfolioViewModel

    @State private var coinName: String = ""
    @State private var coinSymbol: String = ""
    @State private var quantity: String = ""
    @State private var purchasePrice: String = ""       // New: Purchase price per coin input
    @State private var purchaseDate: Date = Date()        // New: Purchase date (defaults to today)

    var body: some View {
        NavigationView {
            Form {
                // Section for coin basic info
                Section(header: Text("Coin Details")) {
                    TextField("Coin Name", text: $coinName)
                    TextField("Coin Symbol", text: $coinSymbol)
                }
                
                // Section for holding details
                Section(header: Text("Holding Details")) {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.decimalPad)
                    TextField("Purchase Price (per coin)", text: $purchasePrice)
                        .keyboardType(.decimalPad)
                    DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                }
                
                // Button to add the holding
                Button(action: addHolding) {
                    Text("Add Holding")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationBarTitle("Add Holding", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func addHolding() {
        // Validate and convert quantity and purchasePrice input strings to Doubles.
        guard let qty = Double(quantity),
              let price = Double(purchasePrice) else {
            // Add appropriate error handling here.
            return
        }
        
        // Compute the cost basis (purchase price per coin * quantity)
        let costBasis = qty * price
        
        // Call the view model's addHolding method.
        // Note: We now supply 'nil' for imageUrl since it isn't entered manually.
        viewModel.addHolding(
            coinName: coinName,
            coinSymbol: coinSymbol,
            quantity: qty,
            currentPrice: 0.0,  // Placeholder; current price will be updated later via API
            costBasis: costBasis,
            imageUrl: nil,      // Provided to satisfy the new parameter in addHolding
            purchaseDate: purchaseDate
        )
        
        presentationMode.wrappedValue.dismiss()
    }
}

struct AddHoldingView_Previews: PreviewProvider {
    static var previews: some View {
        AddHoldingView(viewModel: PortfolioViewModel())
    }
}
