import Foundation
import NovaCrypto
import SubstrateSdk

final class WalletQREncoder: NovaWalletQREncoderProtocol {
    let chainFormat: ChainFormat
    let publicKey: Data

    init(chainFormat: ChainFormat, publicKey: Data) {
        self.chainFormat = chainFormat
        self.publicKey = publicKey
    }

    func encode(receiverInfo: AssetReceiveInfo) throws -> Data {
        let accountId = try Data(hexString: receiverInfo.accountId)

        let address = try accountId.toAddress(using: chainFormat)

        let addressEncoder = AddressQREncoder(addressFormat: chainFormat.qrAddressFormat)

        return try addressEncoder.encode(address: address)
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
    var qrAddressFormat: QRAddressFormat {
        switch self {
        case .ethereum:
            return .ethereum
        case let .substrate(prefix, _):
            return .substrate(type: prefix)
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
    let chainFormat: ChainFormat
    let publicKey: Data

    init(chainFormat: ChainFormat, publicKey: Data) {
        self.chainFormat = chainFormat
        self.publicKey = publicKey
    }

    func createEncoder() -> NovaWalletQREncoderProtocol {
        WalletQREncoder(chainFormat: chainFormat, publicKey: publicKey)
    }

    func createDecoder() -> NovaWalletQRDecoderProtocol {
        WalletQRDecoder(chainFormat: chainFormat)
    }
}
