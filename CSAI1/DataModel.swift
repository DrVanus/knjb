import Foundation

/// Unified Transaction model used in the app to represent both manual and exchange transactions.
struct Transaction: Identifiable, Codable {
    /// Unique identifier for the transaction.
    let id: UUID
    /// The symbol of the cryptocurrency (e.g., "BTC").
    let coinSymbol: String
    /// The date when the transaction occurred.
    let date: Date
    /// The amount of cryptocurrency transacted.
    let quantity: Double
    /// The price per coin at the time of the transaction.
    let pricePerUnit: Double
    /// Indicates whether this is a buy transaction (true) or a sell (false).
    let isBuy: Bool
    /// Flag indicating if this transaction was manually entered (true) or is synced from an exchange/wallet (false).
    let isManual: Bool
    
    /// Initializes a new Transaction.
    /// - Parameters:
    ///   - id: A unique identifier (defaults to a new UUID).
    ///   - coinSymbol: The cryptocurrency symbol.
    ///   - date: The transaction date.
    ///   - quantity: The quantity of cryptocurrency transacted.
    ///   - pricePerUnit: The price per coin at the time of the transaction.
    ///   - isBuy: True for a buy transaction, false for a sell.
    ///   - isManual: True if the transaction is user-entered, false if it’s synced (defaults to true).
    init(id: UUID = UUID(), coinSymbol: String, date: Date, quantity: Double, pricePerUnit: Double, isBuy: Bool, isManual: Bool = true) {
        self.id = id
        self.coinSymbol = coinSymbol
        self.date = date
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
        self.isBuy = isBuy
        self.isManual = isManual
    }
}
