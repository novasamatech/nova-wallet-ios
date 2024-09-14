import Foundation
import Operation_iOS
import CoreData
import BigInt

final class VotingPowerMapper {
    var entityIdentifierFieldName: String { #keyPath(CDVotingPower.identifier) }

    typealias DataProviderModel = VotingPowerLocal
    typealias CoreDataEntity = CDVotingPower
}

extension VotingPowerMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let amount = entity.amount.map { BigUInt($0) ?? 0 } ?? 0

        return VotingPowerLocal(
            chainId: entity.chainId!,
            metaId: entity.metaId!,
            conviction: VotingBasketConvictionLocal(rawType: entity.conviction!),
            amount: amount
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.chainId = model.chainId
        entity.metaId = model.metaId
        entity.conviction = model.conviction.rawValue
        entity.amount = String(model.amount)
    }
}
