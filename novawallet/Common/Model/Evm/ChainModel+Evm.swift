import Foundation
import BigInt

extension AssetModel {
    var isEvm: Bool {
        type == AssetType.evm.rawValue
    }

    var evmContractAddress: AccountAddress? {
        guard isEvm else {
            return nil
        }

        return typeExtras?.stringValue
    }
}

extension ChainModel {
    var allEvmAssets: [AssetModel] {
        assets.filter { $0.isEvm }
    }

    var hasEvmAsset: Bool {
        assets.contains { $0.isEvm }
    }

    var evmChainId: String {
        BigUInt(addressPrefix).serialize().toHex(includePrefix: true)
    }
}
