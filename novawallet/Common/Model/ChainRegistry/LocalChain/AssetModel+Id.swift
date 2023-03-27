import Foundation
import xxHash_Swift

extension AssetModel {
    static func createAssetId(from contractAddress: AccountAddress) -> AssetModel.Id? {
        guard let ethereumAccountId = try? contractAddress.toEthereumAccountId() else {
            return nil
        }

        return XXH32.digest(ethereumAccountId)
    }
}
