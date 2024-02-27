import Foundation

extension NSPredicate {
    static func filterTransactionsBy(
        transactionId: String,
        chainId: ChainModel.Id
    ) -> NSPredicate {
        let transactionIdFilter = filterTransactionsBy(transactionId: transactionId)
        let chainIdFilter = filterTransactionsByChainId(chainId)

        let subfilters = [chainIdFilter, transactionIdFilter]
        return NSCompoundPredicate(andPredicateWithSubpredicates: subfilters)
    }

    static func filterTransactionsBy(
        address: String,
        chainId: ChainModel.Id
    ) -> NSPredicate {
        let senderPredicate = filterTransactionsBySender(address: address)
        let receiverPredicate = filterTransactionsByReceiver(address: address)
        let chainPredicate = filterTransactionsByChainId(chainId)

        let orPredicates = [senderPredicate, receiverPredicate]
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            chainPredicate,
            NSCompoundPredicate(orPredicateWithSubpredicates: orPredicates)
        ])
    }

    static func filterTransactionsBy(
        address: String,
        chainId: ChainModel.Id,
        assetId: UInt32,
        source: TransactionHistoryItemSource?,
        filter: WalletHistoryFilter?
    ) -> NSPredicate {
        let filterByAsset = filterTransactionsBy(
            address: address,
            chainId: chainId,
            assetId: assetId,
            source: source
        )

        if let filter = filter {
            let filterPredicate = filterTransactionsByType(filter)

            return NSCompoundPredicate(andPredicateWithSubpredicates: [filterByAsset, filterPredicate])
        } else {
            return filterByAsset
        }
    }

    static func filterTransactionsBy(
        address: String,
        chainId: ChainModel.Id,
        assetId: UInt32,
        source: TransactionHistoryItemSource?
    ) -> NSPredicate {
        let senderPredicate = filterTransactionsBySender(address: address)
        let receiverPredicate = filterTransactionsByReceiver(address: address)
        let chainPredicate = filterTransactionsByChainId(chainId)
        let assetPredicate = filterTransactionsByAssetId(assetId)
        let swapPredicate = filterSwapTransactionsByAssetId(assetId)

        let orPredicates = [senderPredicate, receiverPredicate]
        let assetsAndSwapsPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [assetPredicate, swapPredicate])
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            chainPredicate,
            assetsAndSwapsPredicate,
            NSCompoundPredicate(orPredicateWithSubpredicates: orPredicates)
        ])

        if let source = source {
            let sourcePredicate = filterTransactionsBySource(source)
            return NSCompoundPredicate(andPredicateWithSubpredicates: [compoundPredicate, sourcePredicate])
        } else {
            return compoundPredicate
        }
    }

    static func filterUtilityAssetTransactionsBy(
        address: String,
        chainId: ChainModel.Id,
        utilityAssetId: UInt32,
        source: TransactionHistoryItemSource?,
        filter: WalletHistoryFilter?
    ) -> NSPredicate {
        let filterByAsset = filterUtilityAssetTransactionsBy(
            address: address,
            chainId: chainId,
            utilityAssetId: utilityAssetId,
            source: source
        )

        if let filter = filter {
            let filterPredicate = filterTransactionsByType(filter)

            return NSCompoundPredicate(andPredicateWithSubpredicates: [filterByAsset, filterPredicate])
        } else {
            return filterByAsset
        }
    }

    static func filterUtilityAssetTransactionsBy(
        address: String,
        chainId: ChainModel.Id,
        utilityAssetId: UInt32,
        source: TransactionHistoryItemSource?
    ) -> NSPredicate {
        let senderPredicate = filterTransactionsBySender(address: address)
        let receiverPredicate = filterTransactionsByReceiver(address: address)
        let chainPredicate = filterTransactionsByChainId(chainId)
        let assetPredicate = filterTransactionsByAssetId(utilityAssetId)
        let swapPredicate = filterSwapTransactionsByAssetId(utilityAssetId)

        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            chainPredicate,
            NSCompoundPredicate(
                orPredicateWithSubpredicates: [
                    senderPredicate,
                    NSCompoundPredicate(andPredicateWithSubpredicates: [
                        assetPredicate,
                        receiverPredicate
                    ]),
                    NSCompoundPredicate(andPredicateWithSubpredicates: [
                        swapPredicate,
                        receiverPredicate
                    ])
                ]
            )
        ])

        if let source = source {
            let sourcePredicate = filterTransactionsBySource(source)
            return NSCompoundPredicate(andPredicateWithSubpredicates: [compoundPredicate, sourcePredicate])
        } else {
            return compoundPredicate
        }
    }

    static func filterTransactionsBy(transactionId: String) -> NSPredicate {
        NSPredicate(
            format: "%K == %@",
            #keyPath(CDTransactionItem.identifier),
            transactionId
        )
    }

    static func filterTransactionsBySender(address: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDTransactionItem.sender), address)
    }

    static func filterTransactionsByReceiver(address: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDTransactionItem.receiver), address)
    }

    static func filterTransactionsByChainId(_ chainId: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDTransactionItem.chainId), chainId)
    }

    static func filterTransactionsByAssetId(_ assetId: UInt32) -> NSPredicate {
        NSPredicate(format: "%K == %d", #keyPath(CDTransactionItem.assetId), Int32(bitPattern: assetId))
    }

    static func filterTransactionsBySource(_ source: TransactionHistoryItemSource) -> NSPredicate {
        NSPredicate(format: "%K == %d", #keyPath(CDTransactionItem.source), source.rawValue)
    }

    static func filterSwapTransactionsByAssetId(_ assetId: UInt32) -> NSPredicate {
        let assetIdIn = NSPredicate(
            format: "%K == %d", #keyPath(CDTransactionItem.swap.assetIdIn),
            Int32(bitPattern: assetId)
        )

        let assetIdOut = NSPredicate(
            format: "%K == %d", #keyPath(CDTransactionItem.swap.assetIdOut),
            Int32(bitPattern: assetId)
        )

        return NSCompoundPredicate(orPredicateWithSubpredicates: [assetIdIn, assetIdOut])
    }

    static func filterTransactionsByType(_ type: WalletHistoryFilter) -> NSPredicate {
        var orPredicates: [NSPredicate] = []

        if type.contains(.transfers) {
            orPredicates.append(filterTransferTransactions())
        }

        if type.contains(.rewardsAndSlashes) {
            orPredicates.append(filterRewardOrSlashTransactions())
        }

        if type.contains(.extrinsics) {
            orPredicates.append(filterExtrinsicTransactions())
        }

        if type.contains(.swaps) {
            orPredicates.append(filterSwapTransactions())
        }

        return NSCompoundPredicate(orPredicateWithSubpredicates: orPredicates)
    }

    static func filterExtrinsicTransactions() -> NSPredicate {
        let transferFilter = filterTransferTransactions()
        let rewardOrSlashFilter = filterRewardOrSlashTransactions()

        return NSCompoundPredicate(
            notPredicateWithSubpredicate: NSCompoundPredicate(
                andPredicateWithSubpredicates: [transferFilter, rewardOrSlashFilter]
            )
        )
    }

    static func filterTransferTransactions() -> NSPredicate {
        let paths = CallCodingPath.substrateTransfers + [.erc20Tranfer, .evmNativeTransfer]

        let predicates = paths.map { filterTransactionsByCodingPath($0) }

        return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
    }

    static func filterSwapTransactions() -> NSPredicate {
        NSPredicate(format: "%K != nil", #keyPath(CDTransactionItem.swap))
    }

    static func filterRewardOrSlashTransactions() -> NSPredicate {
        let paths = [CallCodingPath.reward, CallCodingPath.slash]

        let predicates = paths.map { filterTransactionsByCodingPath($0) }

        return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
    }

    static func filterTransactionsByCodingPath(_ codingPath: CallCodingPath) -> NSPredicate {
        let modulePredicate = NSPredicate(
            format: "%K == %@", #keyPath(CDTransactionItem.moduleName),
            codingPath.moduleName
        )

        let callPredicate = NSPredicate(format: "%K == %@", #keyPath(CDTransactionItem.callName), codingPath.callName)

        return NSCompoundPredicate(andPredicateWithSubpredicates: [modulePredicate, callPredicate])
    }

    static var pushSettings: NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDUserSingleValue.identifier), LocalPushSettings.getIdentifier())
    }

    static var topicSettings: NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDUserSingleValue.identifier), LocalNotificationTopicSettings.getIdentifier())
    }
}
