import Foundation
@testable import novawallet

final class MoneyPresentableMock: MoneyPresentable {
    var formatter: NumberFormatter { NumberFormatter.amount }
    var amount: String = ""
    var precision: Int16 = 2
    let plugin: AmountInputFormatterPluginProtocol? = AddSymbolAmountInputFormatterPlugin()
}

