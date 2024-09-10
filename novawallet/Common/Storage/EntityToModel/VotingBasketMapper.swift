import Foundation
import Operation_iOS
import SubstrateSdk
import CoreData

final class VotingBasketItemMapper {
    var entityIdentifierFieldName: String { #keyPath(CDVotingBasketItem.identifier) }

    typealias DataProviderModel = VotingBasketItemLocal
    typealias CoreDataEntity = CDVotingBasketItem
}

extension VotingBasketItemMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        VotingBasketItemLocal(
            referendumId: ReferendumIdLocal(entity.referendumId),
            chainId: entity.chainId!,
            metaId: entity.metaId!,
            voteType: VotingBasketItemLocal.VoteType(rawValue: entity.voteType!)!,
            conviction: ConvictionLocal(rawType: entity.conviction!)
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
        entity.voteType = model.voteType.rawValue
        entity.conviction = model.conviction.rawValue
    }
}
