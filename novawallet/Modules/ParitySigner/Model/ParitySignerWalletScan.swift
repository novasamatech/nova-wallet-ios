import Foundation
import SubstrateSdk

enum ParitySignerWalletScanError: Error {
    case invalidRootKeyType(UInt8)
}

enum ParitySignerWalletScan {
    struct SingleAddress {
        let address: AccountAddress
        let genesisHash: Data
    }

    enum RootPublicKeyType: UInt8 {
        case ed25519
        case sr25519
        case substrateEcdsa
        case ethereumEcdsa

        var multiassetType: MultiassetCryptoType {
            switch self {
            case .ed25519:
                .ed25519
            case .sr25519:
                .sr25519
            case .substrateEcdsa:
                .substrateEcdsa
            case .ethereumEcdsa:
                .ethereumEcdsa
            }
        }
    }

    struct RootKeysInfo: ScaleCodable {
        static let KeyIdSize: Int = 32

        let rootKeyId: Data
        let publicKeys: [RootPublicKey]

        init(scaleDecoder: ScaleDecoding) throws {
            rootKeyId = try scaleDecoder.readAndConfirm(count: Self.KeyIdSize)
            publicKeys = try [RootPublicKey](scaleDecoder: scaleDecoder)
        }

        func encode(scaleEncoder: ScaleEncoding) throws {
            scaleEncoder.appendRaw(data: rootKeyId)
            try publicKeys.encode(scaleEncoder: scaleEncoder)
        }
    }

    enum RootPublicKey: ScaleCodable {
        case ed25519(Data)
        case sr25519(Data)
        case substrateEcdsa(Data)
        case ethereumEcdsa(Data)

        var type: RootPublicKeyType {
            switch self {
            case .ed25519:
                .ed25519
            case .sr25519:
                .sr25519
            case .substrateEcdsa:
                .substrateEcdsa
            case .ethereumEcdsa:
                .ethereumEcdsa
            }
        }

        var publicKeyData: Data {
            switch self {
            case let .ed25519(pubKey):
                return pubKey
            case let .sr25519(pubKey):
                return pubKey
            case let .substrateEcdsa(pubKey):
                return pubKey
            case let .ethereumEcdsa(pubKey):
                return pubKey
            }
        }

        init(scaleDecoder: ScaleDecoding) throws {
            let rawType = try UInt8(scaleDecoder: scaleDecoder)

            guard let type = RootPublicKeyType(rawValue: rawType) else {
                throw ParitySignerWalletScanError.invalidRootKeyType(rawType)
            }

            switch type {
            case .ed25519:
                let publicKey = try scaleDecoder.readAndConfirm(count: 32)
                self = .ed25519(publicKey)
            case .sr25519:
                let publicKey = try scaleDecoder.readAndConfirm(count: 32)
                self = .sr25519(publicKey)
            case .substrateEcdsa:
                let publicKey = try scaleDecoder.readAndConfirm(count: 33)
                self = .substrateEcdsa(publicKey)
            case .ethereumEcdsa:
                let publicKey = try scaleDecoder.readAndConfirm(count: 33)
                self = .ethereumEcdsa(publicKey)
            }
        }

        func encode(scaleEncoder: ScaleEncoding) throws {
            try type.rawValue.encode(scaleEncoder: scaleEncoder)
            scaleEncoder.appendRaw(data: publicKeyData)
        }
    }

    case singleAddress(SingleAddress)
    case rootKeys(RootKeysInfo)
}
