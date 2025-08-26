import Foundation

enum CurrenciesPallet {
    static let moduleName = "Currencies"

    static var depositedEventPath: EventCodingPath {
        .init(moduleName: Self.moduleName, eventName: "Deposited")
    }
}
