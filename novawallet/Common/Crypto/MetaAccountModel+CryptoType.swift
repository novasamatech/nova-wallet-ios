import Foundation

extension MetaAccountModel {
    var substrateMultiAssetCryptoType: MultiassetCryptoType? {
        substrateCryptoType.flatMap { MultiassetCryptoType(rawValue: $0) }
    }
}
