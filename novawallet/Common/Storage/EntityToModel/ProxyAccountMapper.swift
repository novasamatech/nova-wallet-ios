import Foundation
import Operation_iOS
import CoreData

final class ProxyAccountMapper {
    var entityIdentifierFieldName: String { #keyPath(CDProxy.identifier) }

    typealias DataProviderModel = DelegatedAccount.ProxyAccountModel
    typealias CoreDataEntity = CDProxy
}

extension ProxyAccountMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let accountId = try Data(hexString: entity.proxyAccountId!)
        let type = Proxy.ProxyType(id: entity.type!)

        return DataProviderModel(
            type: type,
            accountId: accountId,
            status: DelegatedAccount.Status(rawValue: entity.status!)!
        )
    }

    func populate(
        entity _: CoreDataEntity,
        from _: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        fatalError("populate(entity:) has not been implemented. The mapper is for fetching only")
    }
}
