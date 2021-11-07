import Foundation
import CommonWallet
import IrohaCrypto
import SubstrateSdk

final class WalletQREncoder: WalletQREncoderProtocol {
    let username: String?
    let chainFormat: ChainFormat
    let publicKey: Data

    private lazy var substrateEncoder = SubstrateQREncoder()

    init(chainFormat: ChainFormat, publicKey: Data, username: String?) {
        self.chainFormat = chainFormat
        self.publicKey = publicKey
        self.username = username
    }

    func encode(receiverInfo: ReceiveInfo) throws -> Data {
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

final class WalletQRDecoder: WalletQRDecoderProtocol {
    private let substrateDecoder: SubstrateQRDecoder
    private let assets: [WalletAsset]

    init(addressPrefix: ChainType, assets: [WalletAsset]) {
        substrateDecoder = SubstrateQRDecoder(chainType: addressPrefix)
        self.assets = assets
    }

    func decode(data: Data) throws -> ReceiveInfo {
        do {
            let info = try substrateDecoder.decode(data: data)

            let accountId = try info.address.toAccountId()

            return ReceiveInfo(
                accountId: accountId.toHex(),
                assetId: assets.first?.identifier,
                amount: nil,
                details: nil
            )
        } catch {
            Logger.shared.error("Did receive error: \(error)")
            throw error
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
        WalletQREncoder(
            chainFormat: chainFormat,
            publicKey: publicKey,
            username: username
        )
    }

    func createDecoder() -> WalletQRDecoderProtocol {
        WalletQRDecoder(addressPrefix: addressPrefix, assets: assets)
    }
}
