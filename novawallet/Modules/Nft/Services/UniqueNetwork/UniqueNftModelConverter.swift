import Foundation
import BigInt
import SubstrateSdk

enum UniqueNftModelConverter {
    static func convert(
        response: UniqueScanNftResponse,
        chain: ChainModel
    ) throws -> [RemoteNftModel] {
        try response.items.enumerated().map { _, item in
            let ownerAccount = try item.owner.toAccountId()
            let identifier = "\(chain.chainId)-\(item.key)"

            return RemoteNftModel(
                identifier: identifier,
                type: NftType.unique.rawValue,
                chainId: chain.chainId,
                ownerId: ownerAccount,
                collectionId: "\(item.collectionId)",
                instanceId: "\(item.tokenId)",
                metadata: item.description?.data(using: .utf8),
                issuanceTotal: nil,
                issuanceMyAmount: nil,
                name: item.name,
                label: nil,
                media: item.image,
                price: nil,
                priceUnits: nil
            )
        }
    }
}
