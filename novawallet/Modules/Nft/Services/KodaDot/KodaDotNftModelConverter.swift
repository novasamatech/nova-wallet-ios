import Foundation
import BigInt

enum KodaDotNftModelConverter {
    static func convert(response: KodaDotNftResponse, chain: ChainModel) throws -> [RemoteNftModel] {
        try response.nftEntities.map { entity in
            let owner = try entity.currentOwner.toAccountId(using: chain.chainFormat)

            let identifier = NftModel.kodaDotIdentifier(for: chain.chainId, identifier: entity.identifier)

            return RemoteNftModel(
                identifier: identifier,
                type: NftType.kodadot.rawValue,
                chainId: chain.chainId,
                ownerId: owner,
                collectionId: entity.collection?.identifier,
                instanceId: entity.identifier,
                metadata: entity.metadata.flatMap { $0.data(using: .utf8) },
                issuanceTotal: entity.collection?.max.flatMap { BigUInt($0) },
                issuanceMyAmount: nil,
                name: entity.name,
                label: entity.serialNumber,
                media: entity.image,
                price: entity.price,
                priceUnits: nil
            )
        }
    }
}
