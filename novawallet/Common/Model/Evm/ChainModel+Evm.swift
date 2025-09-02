import Foundation
import BigInt

extension AssetModel {
    var isEvmAsset: Bool {
        type == AssetType.evmAsset.rawValue
    }

    var isEvmNative: Bool {
        type == AssetType.evmNative.rawValue
    }

    var isAnyEvm: Bool {
        isEvmAsset || isEvmNative
    }

    var evmContractAddress: AccountAddress? {
        guard isEvmAsset else {
            return nil
        }

        return typeExtras?.evmContractAddress
    }
}

extension ChainModel {
    var allEvmAssets: [AssetModel] {
        assets.filter { $0.isEvmAsset }
    }

    var hasEvmAsset: Bool {
        assets.contains { $0.isEvmAsset }
    }

    var evmChainId: String {
        BigUInt(addressPrefix).serialize().toHex(includePrefix: true)
    }
}
