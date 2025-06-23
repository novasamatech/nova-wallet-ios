import Foundation
import NovaCrypto

extension NSPredicate {
    static func filterContactsByTarget(address: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDContactItem.targetAddress), address)
    }

    static func filterRuntimeMetadataItemsBy(identifier: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDRuntimeMetadataItem.identifier), identifier)
    }

    static func filterStorageItemsBy(identifier: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDChainStorageItem.identifier), identifier)
    }

    static func filterByIdPrefix(_ prefix: String) -> NSPredicate {
        NSPredicate(format: "%K BEGINSWITH %@", #keyPath(CDChainStorageItem.identifier), prefix)
    }

    static func filterByStashOrController(_ address: String, chainId: ChainModel.Id) -> NSPredicate {
        let stashFilter = NSPredicate(format: "%K == %@", #keyPath(CDStashItem.stash), address)
        let controllerFiter = NSPredicate(format: "%K == %@", #keyPath(CDStashItem.controller), address)
        let chainIdFilter = NSPredicate(format: "%K == %@", #keyPath(CDStashItem.chainId), chainId)

        let stashOrControllerFilter = NSCompoundPredicate(
            orPredicateWithSubpredicates: [stashFilter, controllerFiter]
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [stashOrControllerFilter, chainIdFilter])
    }

    static func filterMetaAccountByAccountId(_ accountId: AccountId) -> NSPredicate {
        let hexAccountId = accountId.toHex()

        let substrateAccountFilter = NSPredicate(
            format: "%K == %@",
            #keyPath(CDMetaAccount.substrateAccountId), hexAccountId
        )

        let ethereumAccountFilter = NSPredicate(
            format: "%K == %@",
            #keyPath(CDMetaAccount.ethereumAddress), hexAccountId
        )

        let chainAccountFilter = NSPredicate(
            format: "ANY %K == %@",
            #keyPath(CDMetaAccount.chainAccounts.accountId), hexAccountId
        )

        return NSCompoundPredicate(orPredicateWithSubpredicates: [
            substrateAccountFilter,
            ethereumAccountFilter,
            chainAccountFilter
        ])
    }

    static func metaAccountById(_ identifier: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDMetaAccount.metaId), identifier)
    }

    static func selectedMetaAccount() -> NSPredicate {
        NSPredicate(format: "%K == true", #keyPath(CDMetaAccount.isSelected))
    }

    static func relayChains() -> NSPredicate {
        NSPredicate(format: "%K = nil", #keyPath(CDChain.parentId))
    }

    static func chainBy(identifier: ChainModel.Id) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDChain.chainId), identifier)
    }

    static func hasCrowloans() -> NSPredicate {
        NSPredicate(format: "%K == true", #keyPath(CDChain.hasCrowdloans))
    }

    static func assetBalance(chainId: ChainModel.Id, assetId: AssetModel.Id) -> NSPredicate {
        let chainIdPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDAssetBalance.chainId),
            chainId
        )

        let assetIdPredicate = NSPredicate(
            format: "%K == %d",
            #keyPath(CDAssetBalance.assetId),
            assetId
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            chainIdPredicate, assetIdPredicate
        ])
    }

    static func assetBalance(chainAssetIds: Set<ChainAssetId>) -> NSPredicate {
        let predicates = chainAssetIds.map { assetBalance(chainId: $0.chainId, assetId: $0.assetId) }
        return NSCompoundPredicate(orPredicateWithSubpredicates: Array(predicates))
    }

    static func assetBalance(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) -> NSPredicate {
        let accountPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDAssetBalance.chainAccountId),
            accountId.toHex()
        )

        let chainIdPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDAssetBalance.chainId),
            chainId
        )

        let assetIdPredicate = NSPredicate(
            format: "%K == %d",
            #keyPath(CDAssetBalance.assetId),
            assetId
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            accountPredicate, chainIdPredicate, assetIdPredicate
        ])
    }

    static func assetBalance(for chainId: ChainModel.Id, accountId: AccountId) -> NSPredicate {
        let chainPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDAssetBalance.chainId),
            chainId
        )

        let accountPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDAssetBalance.chainAccountId),
            accountId.toHex()
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            accountPredicate, chainPredicate
        ])
    }

    static func assetBalance(
        for accountId: AccountId
    ) -> NSPredicate {
        NSPredicate(
            format: "%K == %@",
            #keyPath(CDAssetBalance.chainAccountId),
            accountId.toHex()
        )
    }

    static func assetLock(chainId: ChainModel.Id, assetId: AssetModel.Id) -> NSPredicate {
        let chainIdPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDAssetLock.chainId),
            chainId
        )

        let assetIdPredicate = NSPredicate(
            format: "%K == %d",
            #keyPath(CDAssetLock.assetId),
            assetId
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            chainIdPredicate, assetIdPredicate
        ])
    }

    static func assetLock(chainAssetIds: Set<ChainAssetId>) -> NSPredicate {
        let predicates = chainAssetIds.map { assetLock(chainId: $0.chainId, assetId: $0.assetId) }
        return NSCompoundPredicate(orPredicateWithSubpredicates: Array(predicates))
    }

    static func assetLock(
        for accountId: AccountId
    ) -> NSPredicate {
        NSPredicate(
            format: "%K == %@",
            #keyPath(CDAssetLock.chainAccountId),
            accountId.toHex()
        )
    }

    static func assetLock(
        for accountId: AccountId,
        chainAssetId: ChainAssetId
    ) -> NSPredicate {
        let accountPredicate = assetLock(for: accountId)

        let chainIdPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDAssetLock.chainId),
            chainAssetId.chainId
        )

        let assetIdPredicate = NSPredicate(
            format: "%K == %d",
            #keyPath(CDAssetLock.assetId),
            chainAssetId.assetId
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            accountPredicate, chainIdPredicate, assetIdPredicate
        ])
    }

    static func assetLock(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        storage: String
    ) -> NSPredicate {
        let accountPredicate = assetLock(for: accountId)

        let chainIdPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDAssetLock.chainId),
            chainAssetId.chainId
        )

        let assetIdPredicate = NSPredicate(
            format: "%K == %d",
            #keyPath(CDAssetLock.assetId),
            chainAssetId.assetId
        )

        let storagePredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDAssetLock.storage),
            storage
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            accountPredicate, chainIdPredicate, assetIdPredicate, storagePredicate
        ])
    }

    static func assetHold(chainId: ChainModel.Id, assetId: AssetModel.Id) -> NSPredicate {
        let chainIdPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDAssetHold.chainId),
            chainId
        )

        let assetIdPredicate = NSPredicate(
            format: "%K == %d",
            #keyPath(CDAssetHold.assetId),
            assetId
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            chainIdPredicate, assetIdPredicate
        ])
    }

    static func assetHold(for accountId: AccountId) -> NSPredicate {
        NSPredicate(
            format: "%K == %@",
            #keyPath(CDAssetHold.chainAccountId),
            accountId.toHex()
        )
    }

    static func assetHold(for accountId: AccountId, chainAssetId: ChainAssetId) -> NSPredicate {
        let accountPredicate = assetHold(for: accountId)

        let chainIdPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDAssetHold.chainId),
            chainAssetId.chainId
        )

        let assetIdPredicate = NSPredicate(
            format: "%K == %d",
            #keyPath(CDAssetHold.assetId),
            chainAssetId.assetId
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            accountPredicate, chainIdPredicate, assetIdPredicate
        ])
    }

    static func nfts(for chainId: ChainModel.Id, ownerId: AccountId) -> NSPredicate {
        let chainPredicate = NSPredicate(format: "%K == %@", #keyPath(CDNft.chainId), chainId)
        let ownerPredicate = NSPredicate(format: "%K == %@", #keyPath(CDNft.ownerId), ownerId.toHex())

        return NSCompoundPredicate(andPredicateWithSubpredicates: [chainPredicate, ownerPredicate])
    }

    static func nfts(for chainAccounts: [(ChainModel.Id, AccountId)]) -> NSPredicate {
        let predicates = chainAccounts.map { nfts(for: $0.0, ownerId: $0.1) }
        return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
    }

    static func nfts(for type: NftType) -> NSPredicate {
        NSPredicate(format: "%K == %d", #keyPath(CDNft.type), type.rawValue)
    }

    static func nftsForTypes(_ types: Set<NftType>) -> NSPredicate {
        let orPredicates = types.map { nfts(for: $0) }
        return NSCompoundPredicate(orPredicateWithSubpredicates: orPredicates)
    }

    static func nfts(for chainAccounts: [(ChainModel.Id, AccountId)], types: Set<NftType>) -> NSPredicate {
        let chainAccountPredicate = nfts(for: chainAccounts)
        let orPredicates = types.map { nfts(for: $0) }
        let typesPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: orPredicates)
        return NSCompoundPredicate(andPredicateWithSubpredicates: [chainAccountPredicate, typesPredicate])
    }

    static func nfts(for chainAccounts: [(ChainModel.Id, AccountId)], type: NftType) -> NSPredicate {
        let chainAccountPredicate = nfts(for: chainAccounts)
        let typePredicate = nfts(for: type)
        return NSCompoundPredicate(andPredicateWithSubpredicates: [chainAccountPredicate, typePredicate])
    }

    static func filterPhishingSitesDomain(_ host: String) -> NSPredicate {
        let separator = "."
        let hostComponents = host.components(separatedBy: separator)

        guard hostComponents.count > 1 else {
            return NSPredicate(format: "%K == %@", #keyPath(CDPhishingSite.identifier), host)
        }

        let predicates: [NSPredicate] = (2 ... hostComponents.count).map { count in
            let possibleHost = hostComponents.suffix(count).joined(separator: separator)
            return NSPredicate(format: "%K == %@", #keyPath(CDPhishingSite.identifier), possibleHost)
        }

        return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
    }

    static func filterFavoriteDApps(by identifier: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDDAppFavorite.identifier), identifier)
    }

    static func filterDAppBrowserTabs(by metaId: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDDAppBrowserTab.metaId), metaId)
    }

    static func filterAuthorizedBrowserDApps(by metaId: String) -> NSPredicate {
        let metaId = NSPredicate(format: "%K == %@", #keyPath(CDDAppSettings.metaId), metaId)
        let source = NSPredicate(format: "%K = nil", #keyPath(CDDAppSettings.source))

        return NSCompoundPredicate(andPredicateWithSubpredicates: [metaId, source])
    }

    static func filterWalletConnectSessions() -> NSPredicate {
        NSPredicate(
            format: "%K == %@", #keyPath(CDDAppSettings.source), DAppTransports.walletConnect
        )
    }

    static func crowdloanContribution(chainIds: Set<ChainModel.Id>) -> NSPredicate {
        let crowdloanTypePredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDExternalBalance.type),
            ExternalAssetBalance.BalanceType.crowdloan.rawValue
        )

        let chainIdPredicates = chainIds.map {
            NSPredicate(format: "%K == %@", #keyPath(CDExternalBalance.chainId), $0)
        }

        let chainIdPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: Array(chainIdPredicates))

        return NSCompoundPredicate(andPredicateWithSubpredicates: [crowdloanTypePredicate, chainIdPredicate])
    }

    static func crowdloanContribution(
        for chainId: ChainModel.Id,
        accountId: AccountId,
        source: String?
    ) -> NSPredicate {
        let accountChainPredicate = crowdloanContribution(for: chainId, accountId: accountId)
        let sourcePredicate = source.map {
            NSPredicate(format: "%K == %@", #keyPath(CDExternalBalance.subtype), $0)
        } ?? NSPredicate(format: "%K = nil", #keyPath(CDExternalBalance.subtype))

        let predicates = [accountChainPredicate, sourcePredicate]
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    static func crowdloanContribution(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) -> NSPredicate {
        let chainPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDExternalBalance.chainId),
            chainId
        )
        let accountPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDExternalBalance.chainAccountId),
            accountId.toHex()
        )

        let typePredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDExternalBalance.type),
            ExternalAssetBalance.BalanceType.crowdloan.rawValue
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [typePredicate, chainPredicate, accountPredicate])
    }

    static func referendums(for chainId: ChainModel.Id) -> NSPredicate {
        NSPredicate(
            format: "%K == %@",
            #keyPath(CDReferendumMetadata.chainId),
            chainId
        )
    }

    static func referendums(for chainId: ChainModel.Id, referendumId: ReferendumIdLocal) -> NSPredicate {
        let chainPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDReferendumMetadata.chainId),
            chainId
        )

        let referendumPredicate = NSPredicate(
            format: "%K == %d",
            #keyPath(CDReferendumMetadata.referendumId),
            referendumId
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [chainPredicate, referendumPredicate])
    }

    static func prices(for currencyId: Int) -> NSPredicate {
        NSPredicate(format: "%K == %d", #keyPath(CDPrice.currency), currencyId)
    }

    static func price(for priceId: String, currencyId: Int) -> NSPredicate {
        let identifier = PriceData.createIdentifier(for: priceId, currencyId: currencyId)

        return NSPredicate(format: "%K == %@", #keyPath(CDPrice.identifier), identifier)
    }

    static func pricesByIds(_ identifiers: [String]) -> NSPredicate {
        let predicates = identifiers.map {
            NSPredicate(format: "%K == %@", #keyPath(CDPrice.identifier), $0)
        }

        return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
    }

    static func votingBasketItems(
        for chainId: ChainModel.Id,
        metaId: String
    ) -> NSPredicate {
        let chainPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDVotingBasketItem.chainId),
            chainId
        )
        let metaAccountPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDVotingBasketItem.metaId),
            metaId
        )

        return NSCompoundPredicate(
            andPredicateWithSubpredicates: [chainPredicate, metaAccountPredicate]
        )
    }

    static func votingPower(
        for chainId: ChainModel.Id,
        metaId: String
    ) -> NSPredicate {
        let chainPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDVotingPower.chainId),
            chainId
        )
        let metaAccountPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDVotingPower.metaId),
            metaId
        )

        return NSCompoundPredicate(
            andPredicateWithSubpredicates: [chainPredicate, metaAccountPredicate]
        )
    }

    static func pendingMultisigOperations(
        for chainId: ChainModel.Id,
        multisigAccountId: AccountId
    ) -> NSPredicate {
        let chainPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDMultisigPendingOperation.chainId),
            chainId
        )
        let accountIdPredicate = NSPredicate(
            format: "%K == %@",
            #keyPath(CDMultisigPendingOperation.multisigAccountId),
            multisigAccountId.toHex()
        )

        return NSCompoundPredicate(
            andPredicateWithSubpredicates: [chainPredicate, accountIdPredicate]
        )
    }

    static func pendingMultisigOperations(multisigAccountId: AccountId) -> NSPredicate {
        NSPredicate(
            format: "%K == %@",
            #keyPath(CDMultisigPendingOperation.multisigAccountId),
            multisigAccountId.toHex()
        )
    }
}
