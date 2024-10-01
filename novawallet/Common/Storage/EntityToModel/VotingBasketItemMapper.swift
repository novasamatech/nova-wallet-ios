import Foundation
import Operation_iOS
import CoreData
import BigInt

final class VotingBasketItemMapper {
    var entityIdentifierFieldName: String { #keyPath(CDVotingBasketItem.identifier) }

    typealias DataProviderModel = VotingBasketItemLocal
    typealias CoreDataEntity = CDVotingBasketItem
}

extension VotingBasketItemMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let amount = entity.amount.map { BigUInt($0) ?? 0 } ?? 0

        return VotingBasketItemLocal(
            referendumId: ReferendumIdLocal(entity.referendumId),
            chainId: entity.chainId!,
            metaId: entity.metaId!,
            amount: amount,
            voteType: VotingBasketItemLocal.VoteType(rawValue: entity.voteType!)!,
            conviction: VotingBasketConvictionLocal(rawType: entity.conviction!)
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.chainId = model.chainId
        entity.referendumId = Int32(model.referendumId)
        entity.metaId = model.metaId
        entity.amount = String(model.amount)
        entity.voteType = model.voteType.rawValue
        entity.conviction = model.conviction.rawValue
    }
}
