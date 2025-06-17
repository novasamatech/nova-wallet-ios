import Foundation
import Operation_iOS
import CoreData

final class MultisigAccountMapper {
    var entityIdentifierFieldName: String { #keyPath(CDMultisig.identifier) }

    typealias DataProviderModel = DelegatedAccount.MultisigAccountModel
    typealias CoreDataEntity = CDMultisig
}

extension MultisigAccountMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let accountId = try Data(hexString: entity.multisigAccountId!)
        let signatory = try Data(hexString: entity.signatory!)

        let otherSignatoriesHex = entity.otherSignatories?.components(separatedBy: ",") ?? []
        let otherSignatories = try otherSignatoriesHex.map { try Data(hexString: $0) }

        return DataProviderModel(
            accountId: accountId,
            signatory: signatory,
            otherSignatories: otherSignatories,
            threshold: Int(entity.threshold),
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
