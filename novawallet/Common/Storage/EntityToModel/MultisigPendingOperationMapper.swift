import Foundation
import Operation_iOS
import SubstrateSdk
import CoreData
import BigInt

final class MultisigPendingOperationMapper {
    var entityIdentifierFieldName: String { #keyPath(CDMultisigPendingOperation.identifier) }

    typealias DataProviderModel = Multisig.PendingOperation
    typealias CoreDataEntity = CDMultisigPendingOperation
}

extension MultisigPendingOperationMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let multisigAccountId = try Data(hexString: entity.multisigAccountId!)
        let callHash = try Data(hexString: entity.callHash!)

        var definition: Multisig.MultisigDefinition?

        if
            let depositor = entity.depositor,
            let approvals = entity.approvals {
            let index = UInt32(bitPattern: entity.index)
            let height = UInt32(bitPattern: entity.height)

            let timepoint = Multisig.MultisigTimepoint(
                height: height,
                index: index
            )

            let deposit = entity.deposit.map { BigUInt($0) ?? 0 } ?? 0
            let depositor = try Data(hexString: depositor)
            let approvals = try approvals.split(by: .comma)
                .map { try Data(hexString: $0) }

            definition = Multisig.MultisigDefinition(
                timepoint: timepoint,
                deposit: deposit,
                depositor: depositor,
                approvals: approvals
            )
        }

        return Multisig.PendingOperation(
            call: entity.call,
            callHash: callHash,
            timestamp: UInt64(bitPattern: entity.timestamp),
            multisigAccountId: multisigAccountId,
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
        entity.callHash = model.callHash.toHexString()
        entity.timestamp = Int64(bitPattern: model.timestamp)
        entity.chainId = model.chainId

        if let multisigDefinition = model.multisigDefinition {
            entity.index = Int32(bitPattern: multisigDefinition.timepoint.index)
            entity.height = Int32(bitPattern: multisigDefinition.timepoint.height)
            entity.depositor = multisigDefinition.depositor.toHexString()
            entity.deposit = String(multisigDefinition.deposit)
            entity.approvals = multisigDefinition.approvals
                .map { $0.toHexString() }
                .joined(with: .comma)
        }

        entity.call = model.call
    }
}
