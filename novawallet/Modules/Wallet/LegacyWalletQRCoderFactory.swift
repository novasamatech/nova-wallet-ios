import Foundation
import CommonWallet
import IrohaCrypto
import SubstrateSdk

final class WalletQREncoder: WalletQREncoderProtocol, NovaWalletQREncoderProtocol {
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

    func encode(receiverInfo: NovaReceiveInfo) throws -> Data {
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

final class WalletQRDecoder: WalletQRDecoderProtocol, NovaWalletQRDecoderProtocol {
    private let chainFormat: ChainFormat
    private let assets: [WalletAsset]

    init(chainFormat: ChainFormat, assets: [WalletAsset]) {
        self.chainFormat = chainFormat
        self.assets = assets
    }

    func decode(data: Data) throws -> ReceiveInfo {
        if SubstrateQR.isSubstrateQR(data: data) {
            let substrateDecoder = SubstrateQRDecoder(
                addressFormat: chainFormat.substrateQRAddressFormat
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
                addressFormat: chainFormat.substrateQRAddressFormat
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

    func decode(data _: Data) throws -> NovaReceiveInfo {
        fatalError()
    }
}

final class LegacyWalletQRCoderFactory: WalletQRCoderFactoryProtocol {
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
        WalletQRDecoder(chainFormat: chainFormat, assets: assets)
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

// TODO: Rename
protocol NovaWalletQRCoderFactoryProtocol {
    func createEncoder() -> NovaWalletQREncoderProtocol
    func createDecoder() -> NovaWalletQRDecoderProtocol
}

protocol NovaWalletQREncoderProtocol {
    func encode(receiverInfo: NovaReceiveInfo) throws -> Data
}

protocol NovaWalletQRDecoderProtocol {
    func decode(data: Data) throws -> NovaReceiveInfo
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
        WalletQRDecoder(chainFormat: chainFormat, assets: [])
    }
}

public struct NovaReceiveInfo: Codable, Equatable {
    public var accountId: String
    public var assetId: String?
    public var amount: AmountDecimal?
    public var details: String?

    public init(accountId: String, assetId: String?, amount: AmountDecimal?, details: String?) {
        self.accountId = accountId
        self.assetId = assetId
        self.amount = amount
        self.details = details
    }
}
