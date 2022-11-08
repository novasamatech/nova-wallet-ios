import Foundation
import RobinHood
import SubstrateSdk
import CoreData

final class ReferendumMetadataMapper {
    var entityIdentifierFieldName: String { #keyPath(CDReferendumMetadata.identifier) }

    typealias DataProviderModel = ReferendumMetadataLocal
    typealias CoreDataEntity = CDReferendumMetadata
}

extension ReferendumMetadataMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let timeline: [ReferendumMetadataLocal.TimelineItem]?

        if let timelineData = entity.timeline {
            timeline = try JSONDecoder().decode(
                [ReferendumMetadataLocal.TimelineItem].self,
                from: timelineData
            )
        } else {
            timeline = nil
        }

        return ReferendumMetadataLocal(
            chainId: entity.chainId!,
            referendumId: ReferendumIdLocal(entity.referendumId),
            title: entity.title,
            content: entity.content,
            proposer: entity.proposer,
            timeline: timeline
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using context: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.chainId = model.chainId
        entity.referendumId = Int32(model.referendumId)
        entity.title = model.title
        entity.content = model.content
        entity.proposer = model.proposer

        if let timeline = model.timeline, !timeline.isEmpty {
            entity.timeline = try JSONEncoder().encode(timeline)
        } else {
            entity.timeline = nil
        }
    }
}
