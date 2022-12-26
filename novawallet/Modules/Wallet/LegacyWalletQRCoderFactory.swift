import Foundation
import IrohaCrypto
import SubstrateSdk

final class WalletQREncoder: NovaWalletQREncoderProtocol {
    let username: String?
    let chainFormat: ChainFormat
    let publicKey: Data

    private lazy var substrateEncoder = SubstrateQREncoder()

    init(chainFormat: ChainFormat, publicKey: Data, username: String?) {
        self.chainFormat = chainFormat
        self.publicKey = publicKey
        self.username = username
    }

    func encode(receiverInfo: AssetReceiveInfo) throws -> Data {
        let accountId = try Data(hexString: receiverInfo.accountId)

        let address = try accountId.toAddress(using: chainFormat)

        let info = SubstrateQRInfo(
            address: address,
            rawPublicKey: publicKey,
            username: username
        )
        return try substrateEncoder.encode(info: info)
    }
}

final class WalletQRDecoder: NovaWalletQRDecoderProtocol {
    private let chainFormat: ChainFormat

    init(chainFormat: ChainFormat) {
        self.chainFormat = chainFormat
    }

    func decode(data _: Data) throws -> AssetReceiveInfo {
        fatalError()
    }
}

extension ChainFormat {
    var substrateQRAddressFormat: QRAddressFormat {
        switch self {
        case .ethereum:
            return .ethereum
        case let .substrate(type):
            return .substrate(type: type)
        }
    }
}

protocol NovaWalletQRCoderFactoryProtocol {
    func createEncoder() -> NovaWalletQREncoderProtocol
    func createDecoder() -> NovaWalletQRDecoderProtocol
}

protocol NovaWalletQREncoderProtocol {
    func encode(receiverInfo: AssetReceiveInfo) throws -> Data
}

protocol NovaWalletQRDecoderProtocol {
    func decode(data: Data) throws -> AssetReceiveInfo
}

final class WalletQRCoderFactory: NovaWalletQRCoderFactoryProtocol {
    let addressPrefix: ChainType
    let chainFormat: ChainFormat
    let publicKey: Data
    let username: String?

    init(
        addressPrefix: ChainType,
        chainFormat: ChainFormat,
        publicKey: Data,
        username: String?
    ) {
        self.addressPrefix = addressPrefix
        self.chainFormat = chainFormat
        self.publicKey = publicKey
        self.username = username
    }

    func createEncoder() -> NovaWalletQREncoderProtocol {
        WalletQREncoder(
            chainFormat: chainFormat,
            publicKey: publicKey,
            username: username
        )
    }

    func createDecoder() -> NovaWalletQRDecoderProtocol {
        WalletQRDecoder(chainFormat: chainFormat)
    }
}
