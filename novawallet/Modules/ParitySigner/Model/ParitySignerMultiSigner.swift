import Foundation
import SubstrateSdk

enum ParitySignerMultiSigner: Equatable {
    case ed25519(_ data: Data)
    case sr25519(_ data: Data)
    case ecdsa(_ data: Data)
}

extension ParitySignerMultiSigner: ScaleCodable {
    init(scaleDecoder: ScaleDecoding) throws {
        let type = try UInt8(scaleDecoder: scaleDecoder)

        switch type {
        case 0:
            let publicKey = try scaleDecoder.readAndConfirm(count: 32)
            self = .ed25519(publicKey)
        case 1:
            let publicKey = try scaleDecoder.readAndConfirm(count: 32)
            self = .sr25519(publicKey)
        case 2:
            let publicKey = try scaleDecoder.readAndConfirm(count: 33)
            self = .ecdsa(publicKey)
        default:
            throw ScaleCodingError.unexpectedDecodedValue
        }
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        switch self {
        case let .ed25519(pubKey):
            try UInt8(0).encode(scaleEncoder: scaleEncoder)
            scaleEncoder.appendRaw(data: pubKey)
        case let .sr25519(pubKey):
            try UInt8(1).encode(scaleEncoder: scaleEncoder)
            scaleEncoder.appendRaw(data: pubKey)
        case let .ecdsa(pubKey):
            try UInt8(2).encode(scaleEncoder: scaleEncoder)
            scaleEncoder.appendRaw(data: pubKey)
        }
    }
}
