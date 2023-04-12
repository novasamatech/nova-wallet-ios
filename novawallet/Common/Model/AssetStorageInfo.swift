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

enum AssetStorageInfo {
    case native(canTransferAll: Bool)
    case statemine(extras: StatemineAssetExtras)
    case orml(info: OrmlTokenStorageInfo)
    case erc20(contractAccount: AccountId)
    case evmNative
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
        case .statemine, .equilibrium:
            guard let extras = try asset.typeExtras?.map(to: StatemineAssetExtras.self) else {
                throw AssetStorageInfoError.unexpectedTypeExtras
            }

            return .statemine(extras: extras)
        case .evmAsset:
            guard let contractAddress = asset.typeExtras?.stringValue else {
                throw AssetStorageInfoError.unexpectedTypeExtras
            }

            let accountId = try contractAddress.toAccountId(using: .ethereum)

            return .erc20(contractAccount: accountId)
        case .evmNative:
            return .evmNative
        case .none:
            let call = CallCodingPath.transferAll
            let canTransferAll = codingFactory.metadata.getCall(
                from: call.moduleName,
                with: call.callName
            ) != nil
            return .native(canTransferAll: canTransferAll)
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
