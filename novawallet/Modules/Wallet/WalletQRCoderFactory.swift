import Foundation
import CommonWallet
import IrohaCrypto
import SubstrateSdk

final class WalletQREncoder: WalletQREncoderProtocol {
    let chainFormat: ChainFormat
    let publicKey: Data

    init(chainFormat: ChainFormat, publicKey: Data) {
        self.chainFormat = chainFormat
        self.publicKey = publicKey
    }

    func encode(receiverInfo: ReceiveInfo) throws -> Data {
        let accountId = try Data(hexString: receiverInfo.accountId)

        let address = try accountId.toAddress(using: chainFormat)

        let addressEncoder = AddressQREncoder(addressFormat: chainFormat.QRAddressFormat)

        return try addressEncoder.encode(address: address)
    }
}

final class WalletQRDecoder: WalletQRDecoderProtocol {
    private let chainFormat: ChainFormat
    private let assets: [WalletAsset]

    init(chainFormat: ChainFormat, assets: [WalletAsset]) {
        self.chainFormat = chainFormat
        self.assets = assets
    }

    func decode(data: Data) throws -> ReceiveInfo {
        if SubstrateQR.isSubstrateQR(data: data) {
            let substrateDecoder = SubstrateQRDecoder(
                addressFormat: chainFormat.QRAddressFormat
            )
            let info = try substrateDecoder.decode(data: data)

            let accountId = try info.address.toAccountId()

            return ReceiveInfo(
                accountId: accountId.toHex(),
                assetId: assets.first?.identifier,
                amount: nil,
                details: nil
            )
        } else {
            let addressDecoder = AddressQRDecoder(
                addressFormat: chainFormat.QRAddressFormat
            )

            let address = try addressDecoder.decode(data: data)

            let accountId = try address.toAccountId(using: chainFormat)

            return ReceiveInfo(
                accountId: accountId.toHex(),
                assetId: assets.first?.identifier,
                amount: nil,
                details: nil
            )
        }
    }
}

final class WalletQRCoderFactory: WalletQRCoderFactoryProtocol {
    let addressPrefix: ChainType
    let chainFormat: ChainFormat
    let publicKey: Data
    let username: String?
    let assets: [WalletAsset]

    init(
        addressPrefix: ChainType,
        chainFormat: ChainFormat,
        publicKey: Data,
        username: String?,
        assets: [WalletAsset]
    ) {
        self.addressPrefix = addressPrefix
        self.chainFormat = chainFormat
        self.publicKey = publicKey
        self.username = username
        self.assets = assets
    }

    func createEncoder() -> WalletQREncoderProtocol {
        WalletQREncoder(chainFormat: chainFormat, publicKey: publicKey)
    }

    func createDecoder() -> WalletQRDecoderProtocol {
        WalletQRDecoder(chainFormat: chainFormat, assets: assets)
    }
}

extension ChainFormat {
    var QRAddressFormat: QRAddressFormat {
        switch self {
        case .ethereum:
            return .ethereum
        case let .substrate(type):
            return .substrate(type: type)
        }
    }
}
