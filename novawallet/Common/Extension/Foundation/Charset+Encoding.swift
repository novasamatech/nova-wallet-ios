import Foundation

extension CharacterSet {
    static var base58: CharacterSet {
        let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        return CharacterSet(charactersIn: alphabet)
    }

    static var hex: CharacterSet {
        let alphabet = "0x123456789ABCDEFabcdef"
        return CharacterSet(charactersIn: alphabet)
    }

    static var address: CharacterSet {
        base58.union(hex)
    }
}
