import Foundation
import RobinHood
import CoreData

final class ChainAccountMapper {
    var entityIdentifierFieldName: String { #keyPath(CDChainAccount.chainId) }

    typealias DataProviderModel = ChainAccountModel
    typealias CoreDataEntity = CDChainAccount
}

extension ChainAccountMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let proxieds: [ProxiedAccountModel] = try entity.proxieds?.compactMap { entity in
            guard let proxiedEntity = entity as? CDProxied else {
                return nil
            }

            let accountId = try Data(hexString: proxiedEntity.proxiedAccountId!)
            let type = Proxy.ProxyType(rawValue: proxiedEntity.type!) ?? .other

            return ProxiedAccountModel(
                type: type,
                accountId: accountId,
                status: ProxiedAccountModel.Status(rawValue: proxiedEntity.status!)!
            )
        } ?? []
        let accountId = try Data(hexString: entity.accountId!)

        return DataProviderModel(
            chainId: entity.chainId!,
            accountId: accountId,
            publicKey: entity.publicKey!,
            cryptoType: UInt8(entity.cryptoType),
            proxieds: Set(proxieds)
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using context: NSManagedObjectContext
    ) throws {
        entity.accountId = model.accountId.toHex()
        entity.chainId = model.chainId
        entity.cryptoType = Int16(bitPattern: UInt16(model.cryptoType))
        entity.publicKey = model.publicKey

        for proxied in model.proxieds {
            let accountId = proxied.accountId.toHex()
            var proxiedAccountEntity = entity.proxieds?.first {
                if let entity = $0 as? CDProxied,
                   entity.type == proxied.type.rawValue,
                   entity.proxiedAccountId == accountId {
                    return true
                } else {
                    return false
                }
            } as? CDProxied

            if proxiedAccountEntity == nil {
                let newEntity = CDProxied(context: context)
                entity.addToProxieds(newEntity)
                proxiedAccountEntity = newEntity
            }
        }
    }
}
