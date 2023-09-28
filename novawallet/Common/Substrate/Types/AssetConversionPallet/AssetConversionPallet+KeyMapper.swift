import Foundation

extension AssetConversionPallet {
    enum PoolKeysMapper {
        static func getMapper() -> AnyMapper<Data, AssetConversionPallet.PoolAssetPair> {
            AnyMapper { _ in
            }
        }
    }
}
