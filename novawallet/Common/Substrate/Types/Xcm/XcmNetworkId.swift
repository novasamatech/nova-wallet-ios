import Foundation

extension Xcm {
    enum NetworkId {
        case any
        case named(_ data: [Data])
        case polkadot
        case kusama
    }
}
