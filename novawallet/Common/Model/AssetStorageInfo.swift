import Foundation
import SubstrateSdk
import BigInt

enum AssetStorageInfoError: Error {
    case unexpectedTypeExtras
}

struct OrmlTokenStorageInfo {
    let currencyId: JSON
    let currencyData: Data
    let module: String
    let existentialDeposit: BigUInt
    let canTransferAll: Bool
}

struct NativeTokenStorageInfo {
    let canTransferAll: Bool
    let transferCallPath: CallCodingPath
}

struct AssetsPalletStorageInfo {
    let assetId: JSON
    let assetIdString: String
    let palletName: String?
}

enum AssetStorageInfo {
    case native(info: NativeTokenStorageInfo)
    case statemine(info: AssetsPalletStorageInfo)
    case orml(info: OrmlTokenStorageInfo)
    case erc20(contractAccount: AccountId)
    case evmNative
    case equilibrium(extras: EquilibriumAssetExtras)
}

extension AssetStorageInfo {
    static func extract(
        from asset: AssetModel,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> AssetStorageInfo {
        let assetType = asset.type.flatMap { AssetType(rawValue: $0) }

        switch assetType {
        case .orml:
            guard let extras = try asset.typeExtras?.map(to: OrmlTokenExtras.self) else {
                throw AssetStorageInfoError.unexpectedTypeExtras
            }

            let info = try createOrmlStorageInfo(from: extras, codingFactory: codingFactory)

            return .orml(info: info)
        case .statemine:
            guard let extras = try asset.typeExtras?.map(to: StatemineAssetExtras.self) else {
                throw AssetStorageInfoError.unexpectedTypeExtras
            }

            let assetId = try StatemineAssetSerializer.decode(
                assetId: extras.assetId,
                palletName: extras.palletName,
                codingFactory: codingFactory
            )

            let info = AssetsPalletStorageInfo(
                assetId: assetId,
                assetIdString: extras.assetId,
                palletName: extras.palletName
            )

            return .statemine(info: info)
        case .evmAsset:
            guard let contractAddress = asset.evmContractAddress else {
                throw AssetStorageInfoError.unexpectedTypeExtras
            }

            let accountId = try contractAddress.toAccountId(using: .ethereum)

            return .erc20(contractAccount: accountId)
        case .evmNative:
            return .evmNative
        case .equilibrium:
            guard let extras = try asset.typeExtras?.map(to: EquilibriumAssetExtras.self) else {
                throw AssetStorageInfoError.unexpectedTypeExtras
            }

            return .equilibrium(extras: extras)
        case .none:
            let canTransferAll = codingFactory.hasCall(for: .transferAll)
            let transferCallPath: CallCodingPath = codingFactory.hasCall(for: .transferAllowDeath) ?
                .transferAllowDeath : .transfer

            let info = NativeTokenStorageInfo(
                canTransferAll: canTransferAll,
                transferCallPath: transferCallPath
            )

            return .native(info: info)
        }
    }

    private static func createOrmlStorageInfo(
        from extras: OrmlTokenExtras,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> OrmlTokenStorageInfo {
        let rawCurrencyId = try Data(hexString: extras.currencyIdScale)

        let decoder = try codingFactory.createDecoder(from: rawCurrencyId)
        let currencyId = try decoder.read(type: extras.currencyIdType)

        let moduleName: String

        let tokensTransfer = CallCodingPath.tokensTransfer
        let transferAllPath: CallCodingPath

        if codingFactory.metadata.getCall(
            from: tokensTransfer.moduleName,
            with: tokensTransfer.callName
        ) != nil {
            moduleName = tokensTransfer.moduleName
            transferAllPath = CallCodingPath.tokensTransferAll
        } else {
            moduleName = CallCodingPath.currenciesTransfer.moduleName
            transferAllPath = CallCodingPath.currenciesTransferAll
        }

        let existentialDeposit = BigUInt(extras.existentialDeposit) ?? 0

        let canTransferAll = codingFactory.metadata.getCall(
            from: transferAllPath.moduleName,
            with: transferAllPath.callName
        ) != nil

        return OrmlTokenStorageInfo(
            currencyId: currencyId,
            currencyData: rawCurrencyId,
            module: moduleName,
            existentialDeposit: existentialDeposit,
            canTransferAll: canTransferAll
        )
    }
}
