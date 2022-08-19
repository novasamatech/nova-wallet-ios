import Foundation

enum BIP32PathJunction {
    case hardened(value: UInt32)
    case soft(value: UInt32)
}

final class LedgerPathBuilder {
    private var pathData = Data()

    func appending(junction: BIP32PathJunction) -> LedgerPathBuilder {
        let numericJunction: UInt32

        switch junction {
        case let .hardened(value):
            numericJunction = UInt32(0x8000_0000) + value
        case let .soft(value):
            numericJunction = value
        }

        pathData.append(contentsOf: numericJunction.bigEndianBytes)

        return self
    }

    func appendingStandardJunctions(coin: UInt32, accountIndex: UInt32) -> LedgerPathBuilder {
        appending(junction: .hardened(value: 44))
            .appending(junction: .hardened(value: coin))
            .appending(junction: .hardened(value: 0))
            .appending(junction: .soft(value: 0))
            .appending(junction: .soft(value: accountIndex))
    }

    func build() -> Data {
        pathData
    }
}
