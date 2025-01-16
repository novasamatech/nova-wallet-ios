import Foundation
import Operation_iOS
import CoreData

extension Multistaking.DashboardItemMythosStakingPart: Identifiable {
    var identifier: String { stakingOption.stringValue }
}

final class StakingDashboardMythosMapper {
    var entityIdentifierFieldName: String { #keyPath(CDStakingDashboardItem.identifier) }

    typealias DataProviderModel = Multistaking.DashboardItemMythosStakingPart
    typealias CoreDataEntity = CDStakingDashboardItem
}

extension StakingDashboardMythosMapper: CoreDataMapperProtocol {
    func populate(
        entity _: CoreDataEntity,
        from _: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {}

    func transform(entity _: CoreDataEntity) throws -> DataProviderModel {
        // we only can write partial state but not read
        fatalError("Unsupported method")
    }
}
