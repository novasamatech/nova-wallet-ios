import Foundation
import SubstrateSdk

enum PolkadotVaultFeatures {
    case bulkOperations
    case dynamicDerivations
    case unknown(UInt8)
}

extension PolkadotVaultFeatures: ScaleCodable {
    init(scaleDecoder: ScaleDecoding) throws {
        let type = try UInt8(scaleDecoder: scaleDecoder)

        switch type {
        case 0:
            self = .bulkOperations
        case 1:
            self = .dynamicDerivations
        default:
            self = .unknown(type)
        }
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        switch self {
        case .bulkOperations:
            try UInt8(0).encode(scaleEncoder: scaleEncoder)
        case .dynamicDerivations:
            try UInt8(1).encode(scaleEncoder: scaleEncoder)
        case let .unknown(type):
            try UInt8(type).encode(scaleEncoder: scaleEncoder)
        }
    }
}
