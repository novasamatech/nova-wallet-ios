import Foundation
import SubstrateSdk

enum ParitySignerExportAddress {
    case version1(InfoV1)
    case version2(InfoV2)
}

extension ParitySignerExportAddress {
    struct DerivedKey {
        let publicKeyOrAddress: String
        let derivationPath: String?
        let encryption: ParitySignerSigningAlgo
        let genesisHash: H256
    }

    struct Keyset {
        let name: String
        let multisigner: ParitySignerMultiSigner
        let derivedKeys: [DerivedKey]
    }

    struct InfoV1 {
        let keysets: [Keyset]
    }

    struct InfoV2 {
        let keyset: Keyset
        let features: [PolkadotVaultFeatures]
    }

    var keysets: [ParitySignerExportAddress.Keyset] {
        switch self {
        case let .version1(info):
            return info.keysets
        case let .version2(info):
            return [info.keyset]
        }
    }
}

extension ParitySignerExportAddress: ScaleDecodable {
    init(scaleDecoder: ScaleDecoding) throws {
        let type = try UInt8(scaleDecoder: scaleDecoder)

        switch type {
        case 0:
            let info = try InfoV1(scaleDecoder: scaleDecoder)
            self = .version1(info)
        case 1:
            let info = try InfoV2(scaleDecoder: scaleDecoder)
            self = .version2(info)
        default:
            throw ScaleCodingError.unexpectedDecodedValue
        }
    }
}

extension ParitySignerExportAddress.InfoV1: ScaleDecodable {
    init(scaleDecoder: ScaleDecoding) throws {
        keysets = try [ParitySignerExportAddress.Keyset](scaleDecoder: scaleDecoder)
    }
}

extension ParitySignerExportAddress.InfoV2: ScaleDecodable {
    init(scaleDecoder: ScaleDecoding) throws {
        keyset = try ParitySignerExportAddress.Keyset(scaleDecoder: scaleDecoder)
        features = try [PolkadotVaultFeatures](scaleDecoder: scaleDecoder)
    }
}

extension ParitySignerExportAddress.Keyset: ScaleCodable {
    init(scaleDecoder: ScaleDecoding) throws {
        name = try String(scaleDecoder: scaleDecoder)
        multisigner = try ParitySignerMultiSigner(scaleDecoder: scaleDecoder)
        derivedKeys = try [ParitySignerExportAddress.DerivedKey](scaleDecoder: scaleDecoder)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        try name.encode(scaleEncoder: scaleEncoder)
        try multisigner.encode(scaleEncoder: scaleEncoder)
        try derivedKeys.encode(scaleEncoder: scaleEncoder)
    }
}

extension ParitySignerExportAddress.DerivedKey: ScaleCodable {
    init(scaleDecoder: ScaleDecoding) throws {
        publicKeyOrAddress = try String(scaleDecoder: scaleDecoder)
        let optDerivationPath = try ScaleOption<String>(scaleDecoder: scaleDecoder)

        switch optDerivationPath {
        case .none:
            derivationPath = nil
        case let .some(value):
            derivationPath = value
        }

        encryption = try ParitySignerSigningAlgo(scaleDecoder: scaleDecoder)
        genesisHash = try H256(scaleDecoder: scaleDecoder)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        try publicKeyOrAddress.encode(scaleEncoder: scaleEncoder)

        if let derivationPath {
            try ScaleOption.some(value: derivationPath).encode(scaleEncoder: scaleEncoder)
        } else {
            try ScaleOption<String>.none.encode(scaleEncoder: scaleEncoder)
        }

        try encryption.encode(scaleEncoder: scaleEncoder)
        try genesisHash.encode(scaleEncoder: scaleEncoder)
    }
}
