import Foundation

protocol AmountInputFormatterPluginProtocol {
    func preProccessAmount(_ amount: String) -> String
    func postProccesAmount(_ amount: String) -> String
    func processAvailableCharacters(_ characterSet: CharacterSet) -> CharacterSet
    func currentOffset(in amount: String) -> Int?
}

struct AddSymbolAmountInputFormatterPlugin: AmountInputFormatterPluginProtocol {
    var symbol = "%"
    var separator = " "

    func preProccessAmount(_ amount: String) -> String {
        guard amount.hasSuffix(symbol) else {
            return amount
        }

        let count = amount.hasSuffix(separator + symbol) ? symbol.count + separator.count : symbol.count

        let offset = amount.count - count
        let index = amount.index(amount.startIndex, offsetBy: offset)
        return String(amount.prefix(upTo: index))
    }

    func postProccesAmount(_ amount: String) -> String {
        guard !amount.isEmpty else {
            return ""
        }
        return [amount, symbol].joined(separator: separator)
    }

    func processAvailableCharacters(_ characterSet: CharacterSet) -> CharacterSet {
        characterSet.union(CharacterSet(charactersIn: symbol).inverted)
    }

    func currentOffset(in amount: String) -> Int? {
        guard amount.hasSuffix(symbol) else {
            return nil
        }
        let count = amount.hasSuffix(separator + symbol) ? symbol.count + separator.count : symbol.count
        return amount.count - count
    }
}
