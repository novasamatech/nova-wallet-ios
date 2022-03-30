import Foundation
import SubstrateSdk
import BigInt

enum AssetStorageInfoError: Error {
    case unexpectedTypeExtras
}

enum AssetStorageInfo {
    case native
    case statemine(extras: StatemineAssetExtras)
    case orml(currencyId: JSON, currencyData: Data, module: String, existentialDeposit: BigUInt)
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

            let rawCurrencyId = try Data(hexString: extras.currencyIdScale)

            let decoder = try codingFactory.createDecoder(from: rawCurrencyId)
            let currencyId = try decoder.read(type: extras.currencyIdType)

            let moduleName: String

            let tokensTransfer = CallCodingPath.tokensTransfer
            if codingFactory.metadata.getCall(
                from: tokensTransfer.moduleName,
                with: tokensTransfer.callName
            ) != nil {
                moduleName = tokensTransfer.moduleName
            } else {
                moduleName = CallCodingPath.currenciesTransfer.moduleName
            }

            let existentialDeposit = BigUInt(extras.existentialDeposit) ?? 0

            return .orml(
                currencyId: currencyId,
                currencyData: rawCurrencyId,
                module: moduleName,
                existentialDeposit: existentialDeposit
            )
        case .statemine:
            guard let extras = try asset.typeExtras?.map(to: StatemineAssetExtras.self) else {
                throw AssetStorageInfoError.unexpectedTypeExtras
            }

            return .statemine(extras: extras)
        case .none:
            return .native
        }
    }
}
