import Foundation
import Operation_iOS
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

        let multisig: DelegatedAccount.MultisigAccountModel? = try transform(multisigEntity: entity.multisig)

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
            type: MetaAccountModelType(rawValue: UInt8(bitPattern: Int8(entity.type)))!,
            multisig: multisig
        )
    }

    func transform(multisigEntity: CDMultisig?) throws -> DelegatedAccount.MultisigAccountModel? {
        guard
            let multisigEntity,
            let detectedOnChain = multisigEntity.detectedOnChain
        else { return nil }

        let threshold = Int(multisigEntity.threshold)
        let multisigAccountId = try Data(hexString: multisigEntity.multisigAccountId!)
        let signatoryAccountId = try Data(hexString: multisigEntity.signatory!)
        let otherSignatories = try multisigEntity.otherSignatories?
            .split(by: .comma)
            .compactMap { try Data(hexString: $0) } ?? []

        let status = DelegatedAccount.Status(rawValue: multisigEntity.status!)!

        return DelegatedAccount.MultisigAccountModel(
            detectedOnChain: detectedOnChain,
            accountId: multisigAccountId,
            signatory: signatoryAccountId,
            otherSignatories: otherSignatories,
            threshold: threshold,
            status: status
        )
    }

    func transform(chainAccountEntity: CDChainAccount) throws -> ChainAccountModel {
        let proxyModel = try chainAccountEntity.proxy.map {
            let accountId = try Data(hexString: $0.proxyAccountId!)
            let type = Proxy.ProxyType(id: $0.type!)

            return DelegatedAccount.ProxyAccountModel(
                type: type,
                accountId: accountId,
                status: DelegatedAccount.Status(rawValue: $0.status!)!
            )
        }

        let multisigModel = try transform(multisigEntity: chainAccountEntity.multisig)

        let accountId = try Data(hexString: chainAccountEntity.accountId!)

        return ChainAccountModel(
            chainId: chainAccountEntity.chainId!,
            accountId: accountId,
            publicKey: chainAccountEntity.publicKey!,
            cryptoType: UInt8(chainAccountEntity.cryptoType),
            proxy: proxyModel,
            multisig: multisigModel
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

        if let multisig = model.multisig {
            if entity.multisig == nil {
                let multisig = CDMultisig(context: context)
                multisig.metaAccount = entity
                entity.multisig = multisig
            }
            try populateMultisigEntity(
                entity.multisig,
                from: multisig
            )
        }

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

        if let proxy = model.proxy {
            if chainAccounEntity.proxy == nil {
                let proxy = CDProxy(context: context)
                proxy.chainAccount = chainAccounEntity
                chainAccounEntity.proxy = proxy
            }
            chainAccounEntity.proxy?.type = proxy.type.id
            chainAccounEntity.proxy?.proxyAccountId = proxy.accountId.toHex()
            chainAccounEntity.proxy?.status = proxy.status.rawValue
            chainAccounEntity.proxy?.identifier = proxy.identifier
        } else {
            chainAccounEntity.proxy = nil
        }

        if let multisig = model.multisig {
            if chainAccounEntity.multisig == nil {
                let multisig = CDMultisig(context: context)
                multisig.chainAccount = chainAccounEntity
                chainAccounEntity.multisig = multisig
            }
            try populateMultisigEntity(
                chainAccounEntity.multisig,
                from: multisig
            )
        } else {
            chainAccounEntity.multisig = nil
        }
    }

    func populateMultisigEntity(
        _ entity: CDMultisig?,
        from model: DelegatedAccount.MultisigAccountModel
    ) throws {
        entity?.detectedOnChain = model.detectedOnChain
        entity?.multisigAccountId = model.accountId.toHex()
        entity?.signatory = model.signatory.toHex()
        entity?.otherSignatories = model.otherSignatories
            .map { $0.toHex() }
            .joined(with: .comma)
        entity?.threshold = Int64(model.threshold)
        entity?.status = model.status.rawValue
        entity?.identifier = model.identifier
    }
}

extension Proxy.ProxyType {
    init(id: String) {
        switch id {
        case "any":
            self = .any
        case "nonTransfer":
            self = .nonTransfer
        case "governance":
            self = .governance
        case "staking":
            self = .staking
        case "nominationPools":
            self = .nominationPools
        case "identityJudgement":
            self = .identityJudgement
        case "cancelProxy":
            self = .cancelProxy
        case "auction":
            self = .auction
        default:
            self = .other(id)
        }
    }

    var id: String {
        switch self {
        case .any:
            return "any"
        case .nonTransfer:
            return "nonTransfer"
        case .governance:
            return "governance"
        case .staking:
            return "staking"
        case .nominationPools:
            return "nominationPools"
        case .identityJudgement:
            return "identityJudgement"
        case .cancelProxy:
            return "cancelProxy"
        case .auction:
            return "auction"
        case let .other(value):
            return value
        }
    }
}
