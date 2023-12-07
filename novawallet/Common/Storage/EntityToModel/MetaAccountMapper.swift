import Foundation
import RobinHood
import CoreData

final class MetaAccountMapper {
    var entityIdentifierFieldName: String { #keyPath(CDMetaAccount.metaId) }

    typealias DataProviderModel = MetaAccountModel
    typealias CoreDataEntity = CDMetaAccount
}

extension MetaAccountMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let chainAccounts: [ChainAccountModel] = try entity.chainAccounts?.compactMap { entity in
            guard let chainAccountEntity = entity as? CDChainAccount else {
                return nil
            }

            return try transform(chainAccountEntity: chainAccountEntity)
        } ?? []

        let substrateAccountId = try entity.substrateAccountId.map { try Data(hexString: $0) }
        let substrateCryptoType = UInt8(bitPattern: Int8(entity.substrateCryptoType))

        let ethereumAddress = try entity.ethereumAddress.map { try Data(hexString: $0) }

        return DataProviderModel(
            metaId: entity.metaId!,
            name: entity.name!,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: entity.substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: entity.ethereumPublicKey,
            chainAccounts: Set(chainAccounts),
            type: MetaAccountModelType(rawValue: UInt8(bitPattern: Int8(entity.type)))!
        )
    }

    func transform(chainAccountEntity: CDChainAccount) throws -> ChainAccountModel {
        let proxiedModel = try chainAccountEntity.proxied.map {
            let accountId = try Data(hexString: $0.proxiedAccountId!)
            let type = Proxy.ProxyType(rawValue: $0.type!) ?? .other

            return ProxiedAccountModel(
                type: type,
                accountId: accountId,
                status: ProxiedAccountModel.Status(rawValue: $0.status!)!
            )
        }

        let accountId = try Data(hexString: chainAccountEntity.accountId!)

        return ChainAccountModel(
            chainId: chainAccountEntity.chainId!,
            accountId: accountId,
            publicKey: chainAccountEntity.publicKey!,
            cryptoType: UInt8(chainAccountEntity.cryptoType),
            proxied: proxiedModel
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using context: NSManagedObjectContext
    ) throws {
        entity.metaId = model.metaId
        entity.name = model.name
        entity.substrateAccountId = model.substrateAccountId?.toHex()
        entity.substrateCryptoType = model.substrateCryptoType.map { Int16(bitPattern: UInt16($0)) } ?? 0
        entity.substratePublicKey = model.substratePublicKey
        entity.ethereumPublicKey = model.ethereumPublicKey
        entity.ethereumAddress = model.ethereumAddress?.toHex()
        entity.type = Int16(bitPattern: UInt16(model.type.rawValue))

        for chainAccount in model.chainAccounts {
            var chainAccountEntity = entity.chainAccounts?.first {
                if let entity = $0 as? CDChainAccount,
                   entity.chainId == chainAccount.chainId {
                    return true
                } else {
                    return false
                }
            } as? CDChainAccount

            if chainAccountEntity == nil {
                let newEntity = CDChainAccount(context: context)
                entity.addToChainAccounts(newEntity)
                chainAccountEntity = newEntity
            }

            try populate(chainAccounEntity: chainAccountEntity!, from: chainAccount, using: context)
        }
    }

    func populate(
        chainAccounEntity: CDChainAccount,
        from model: ChainAccountModel,
        using context: NSManagedObjectContext
    ) throws {
        chainAccounEntity.accountId = model.accountId.toHex()
        chainAccounEntity.chainId = model.chainId
        chainAccounEntity.cryptoType = Int16(bitPattern: UInt16(model.cryptoType))
        chainAccounEntity.publicKey = model.publicKey

        if let proxied = model.proxied {
            if chainAccounEntity.proxied == nil {
                chainAccounEntity.proxied = CDProxied(context: context)
            }
            chainAccounEntity.proxied?.type = proxied.type.rawValue
            chainAccounEntity.proxied?.proxiedAccountId = proxied.accountId.toHex()
            chainAccounEntity.proxied?.status = proxied.status.rawValue
        } else {
            chainAccounEntity.proxied = nil
        }
    }
}
