import Foundation
import CoreData
import Operation_iOS

extension Multistaking.ResolvedAccount: Identifiable {
    var identifier: String {
        Self.createIdentifier(from: walletAccountId, stakingOption: stakingOption)
    }

    static func createIdentifier(from walletAccountId: AccountId, stakingOption: Multistaking.Option) -> String {
        walletAccountId.toHex() + "-" + stakingOption.stringValue
    }
}

final class StakingResolvedAccountMapper {
    var entityIdentifierFieldName: String { #keyPath(CDStakingAccount.identifier) }

    typealias DataProviderModel = Multistaking.ResolvedAccount
    typealias CoreDataEntity = CDStakingAccount
}

extension StakingResolvedAccountMapper: CoreDataMapperProtocol {
    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.chainId = model.stakingOption.chainAssetId.chainId
        entity.assetId = Int32(bitPattern: model.stakingOption.chainAssetId.assetId)
        entity.stakingType = model.stakingOption.type.rawValue
        entity.walletAccountId = model.walletAccountId.toHex()
        entity.resolvedAccountId = model.resolvedAccountId.toHex()
        entity.rewardsAccountId = model.rewardsAccountId?.toHex()
    }

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let chainAssetId = ChainAssetId(
            chainId: entity.chainId!,
            assetId: AssetModel.Id(bitPattern: entity.assetId)
        )

        let stakingType = StakingType(rawType: entity.stakingType)
        let stakingOption = Multistaking.Option(
            chainAssetId: chainAssetId,
            type: stakingType
        )

        let walletAccountId = try Data(hexString: entity.walletAccountId!)
        let resolvedAccountId = try Data(hexString: entity.resolvedAccountId!)
        let rewardsAccountId = try entity.rewardsAccountId.map { try Data(hexString: $0) }

        return .init(
            stakingOption: stakingOption,
            walletAccountId: walletAccountId,
            resolvedAccountId: resolvedAccountId,
            rewardsAccountId: rewardsAccountId
        )
    }
}
