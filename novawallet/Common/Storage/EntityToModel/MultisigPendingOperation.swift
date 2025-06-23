import Foundation
import Operation_iOS
import SubstrateSdk
import CoreData

final class MultisigPendingOperationMapper {
    var entityIdentifierFieldName: String { #keyPath(CDMultisigPendingOperation.identifier) }

    typealias DataProviderModel = Multisig.PendingOperation
    typealias CoreDataEntity = CDMultisigPendingOperation
}

extension MultisigPendingOperationMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let multisigAccountId = try Data(hexString: entity.multisigAccountId!)
        let signatory = try Data(hexString: entity.signatory!)
        let callHash = try Data(hexString: entity.callHash!)

        let index = UInt32(entity.index)
        let height = UInt32(entity.height)

        let timepoint = Multisig.MultisigTimepoint(
            height: height,
            index: index
        )

        let depositor = try Data(hexString: entity.depositor!)
        let approvals = try entity.approvals?.split(by: .comma)
            .map { try Data(hexString: $0) } ?? []

        let definition = Multisig.MultisigDefinition(
            timepoint: timepoint,
            depositor: depositor,
            approvals: approvals
        )

        let call: JSON? = if let callData = entity.call {
            try JSONDecoder().decode(JSON.self, from: callData)
        } else {
            nil
        }

        return Multisig.PendingOperation(
            call: call,
            callHash: callHash,
            multisigAccountId: multisigAccountId,
            signatory: signatory,
            chainId: entity.chainId!,
            multisigDefinition: definition
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.multisigAccountId = model.multisigAccountId.toHexString()
        entity.signatory = model.signatory.toHexString()
        entity.callHash = model.callHash.toHexString()
        entity.chainId = model.chainId

        entity.index = Int32(model.multisigDefinition.timepoint.index)
        entity.height = Int32(model.multisigDefinition.timepoint.height)
        entity.depositor = model.multisigDefinition.depositor.toHexString()
        entity.approvals = model.multisigDefinition.approvals
            .map { $0.toHexString() }
            .joined(with: .comma)

        if let call = model.call {
            entity.call = try JSONEncoder().encode(call)
        }
    }
}
