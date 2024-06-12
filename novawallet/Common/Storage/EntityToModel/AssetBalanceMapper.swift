import Foundation
import Operation_iOS
import CoreData
import BigInt

final class AssetBalanceMapper {
    var entityIdentifierFieldName: String { #keyPath(CDAssetBalance.identifier) }

    typealias DataProviderModel = AssetBalance
    typealias CoreDataEntity = CDAssetBalance
}

extension AssetBalanceMapper: CoreDataMapperProtocol {
    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.chainAccountId = model.accountId.toHex()
        entity.chainId = model.chainAssetId.chainId
        entity.assetId = Int32(bitPattern: model.chainAssetId.assetId)
        entity.freeInPlank = String(model.freeInPlank)
        entity.reservedInPlank = String(model.reservedInPlank)
        entity.frozenInPlank = String(model.frozenInPlank)
        entity.transferrableMode = model.transferrableMode.toRepositoryValue()
        entity.edCountMode = model.edCountMode.toRepositoryValue()
        entity.blocked = model.blocked
    }

    func transform(entity: CDAssetBalance) throws -> AssetBalance {
        let free = entity.freeInPlank.map { BigUInt($0) ?? 0 } ?? 0
        let reserved = entity.reservedInPlank.map { BigUInt($0) ?? 0 } ?? 0
        let frozen = entity.frozenInPlank.map { BigUInt($0) ?? 0 } ?? 0

        guard
            let transferrableMode = AssetBalance.TransferrableMode(
                fromRepositoryValue: entity.transferrableMode
            ) else {
            throw CommonError.dataCorruption
        }

        guard
            let edCountMode = AssetBalance.ExistentialDepositCountMode(
                fromRepositoryValue: entity.edCountMode
            ) else {
            throw CommonError.dataCorruption
        }

        let accountId = try Data(hexString: entity.chainAccountId!)

        return AssetBalance(
            chainAssetId: ChainAssetId(
                chainId: entity.chainId!,
                assetId: UInt32(bitPattern: entity.assetId)
            ),
            accountId: accountId,
            freeInPlank: free,
            reservedInPlank: reserved,
            frozenInPlank: frozen,
            edCountMode: edCountMode,
            transferrableMode: transferrableMode,
            blocked: entity.blocked
        )
    }
}

extension AssetBalance.TransferrableMode {
    func toRepositoryValue() -> Int16 {
        switch self {
        case .regular:
            return 0
        case .fungibleTrait:
            return 1
        }
    }

    init?(fromRepositoryValue: Int16) {
        switch fromRepositoryValue {
        case 0:
            self = .regular
        case 1:
            self = .fungibleTrait
        default:
            return nil
        }
    }
}

extension AssetBalance.ExistentialDepositCountMode {
    func toRepositoryValue() -> Int16 {
        switch self {
        case .basedOnFree:
            return 0
        case .basedOnTotal:
            return 1
        }
    }

    init?(fromRepositoryValue: Int16) {
        switch fromRepositoryValue {
        case 0:
            self = .basedOnFree
        case 1:
            self = .basedOnTotal
        default:
            return nil
        }
    }
}
