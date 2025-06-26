import Foundation
import SubstrateSdk

enum ParitySignerSigningAlgo: UInt8 {
    case ed25519
    case sr25519
    case substrateEcdsa
    case ethereumEcdsa
}

extension ParitySignerSigningAlgo: ScaleCodable {
    init(scaleDecoder: ScaleDecoding) throws {
        let type = try UInt8(scaleDecoder: scaleDecoder)

        guard let value = ParitySignerSigningAlgo(rawValue: type) else {
            throw ScaleCodingError.unexpectedDecodedValue
        }

        self = value
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        try rawValue.encode(scaleEncoder: scaleEncoder)
    }
}
