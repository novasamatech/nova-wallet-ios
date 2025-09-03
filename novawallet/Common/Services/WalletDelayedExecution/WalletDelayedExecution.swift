import Foundation

protocol WalletDelayedExecVerifing {
    func executesCallWithDelay(_ wallet: MetaAccountModel, chain: ChainModel) -> Bool
}

/**
 *     The implemetation checks for a given wallet whethere there is reachable delegate wallet that delays call
 *     execution
 */
final class WalletDelayedExecVerifier {
    let allWallets: [MetaAccountModel.Id: MetaAccountModel]

    init(allWallets: [MetaAccountModel.Id: MetaAccountModel]) {
        self.allWallets = allWallets
    }
}

extension WalletDelayedExecVerifier: WalletDelayedExecVerifing {
    func executesCallWithDelay(_ wallet: MetaAccountModel, chain: ChainModel) -> Bool {
        guard wallet.isDelegated() else {
            return false
        }

        guard !wallet.delaysCallExecution(in: chain) else {
            return true
        }

        let metaIdsByDelegateId: [AccountId: [MetaAccountModel.Id]] = allWallets.values.reduce(
            into: [:]
        ) { accum, wallet in
            guard
                let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
                return
            }

            let prevList = accum[accountId] ?? []
            accum[accountId] = prevList + [wallet.metaId]
        }

        var prevMetaIds: Set<MetaAccountModel.Id> = [wallet.metaId]
        var currentMetaIds = prevMetaIds

        repeat {
            let newMetaIds: [MetaAccountModel.Id] = currentMetaIds.flatMap { metaId in
                guard
                    let wallet = allWallets[metaId],
                    let delegation = wallet.getDelegateIdentifier(),
                    delegation.existsInChainWithId(chain.chainId) else {
                    return [MetaAccountModel.Id]()
                }

                return metaIdsByDelegateId[delegation.delegateAccountId] ?? []
            }

            let nextMetaIds = Set(newMetaIds).union(currentMetaIds)

            let hasDelayedExecWallets = nextMetaIds.subtracting(currentMetaIds).contains { metaId in
                guard let wallet = allWallets[metaId] else {
                    return false
                }

                return wallet.delaysCallExecution(in: chain)
            }

            if hasDelayedExecWallets {
                return true
            }

            prevMetaIds = currentMetaIds
            currentMetaIds = Set(nextMetaIds)
        } while prevMetaIds != currentMetaIds

        return false
    }
}
