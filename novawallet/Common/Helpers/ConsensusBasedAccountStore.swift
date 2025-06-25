import Foundation

struct ConsensusBasedAccountModel {
    let consensusAccounts: [ConsensusAccount]
    let customDerivationAccounts: [ChainAccount]
    let evmAccounts: [ChainAccount]
    let solochainAccounts: [ChainAccount]
}

extension ConsensusBasedAccountModel {
    struct ConsensusAccount {
        let relay: ChainModel
        let accountId: AccountId
        let chains: [ChainModel]

        func insertingChain(_ chain: ChainModel) -> Self {
            ConsensusAccount(
                relay: relay,
                accountId: accountId,
                chains: chains + [chain]
            )
        }
    }

    struct ChainAccount {
        let accountId: AccountId
        let chain: ChainModel
    }
}

enum ConsensusBasedAccountModelFactory {
    static func createFromAccounts(
        _ accounts: [ChainModel.Id: AccountId],
        sortedChains: [ChainModel]
    ) -> ConsensusBasedAccountModel {
        let consensusIds = Set(sortedChains.compactMap(\.parentId)).intersection(Set(accounts.keys))

        let consensusAccounts = extractConsensusAccounts(
            accounts,
            sortedChains: sortedChains,
            consensusIds: consensusIds
        )

        let chainsWithAccountIds = sortedChains.filter { accounts[$0.chainId] != nil }

        let customDerivationAccounts = extractCustomDerivationAccounts(accounts, sortedChains: chainsWithAccountIds)
        let evmAccounts = extractEvmAccounts(accounts, sortedChains: chainsWithAccountIds)
        let solochainAccounts = extractSolochainsAccounts(
            accounts,
            sortedChains: chainsWithAccountIds,
            consensusIds: consensusIds
        )

        return ConsensusBasedAccountModel(
            consensusAccounts: consensusAccounts,
            customDerivationAccounts: customDerivationAccounts,
            evmAccounts: evmAccounts,
            solochainAccounts: solochainAccounts
        )
    }
}

private extension ConsensusBasedAccountModelFactory {
    static func extractConsensusAccounts(
        _ accounts: [ChainModel.Id: AccountId],
        sortedChains: [ChainModel],
        consensusIds: Set<ChainModel.Id>
    ) -> [ConsensusBasedAccountModel.ConsensusAccount] {
        let consensusChains = sortedChains.filter { !$0.isEthereumBased && consensusIds.contains($0.chainId) }

        let nonEvmChains = sortedChains.filter { !$0.isEthereumBased }

        return consensusChains.compactMap { relay in
            guard let accountId = accounts[relay.chainId] else {
                return nil
            }

            let chains = nonEvmChains.filter { chain in
                chain.chainId == relay.chainId ||
                    (chain.parentId == relay.chainId && accounts[chain.chainId] == nil)
            }

            return ConsensusBasedAccountModel.ConsensusAccount(
                relay: relay,
                accountId: accountId,
                chains: chains
            )
        }
    }

    static func extractCustomDerivationAccounts(
        _ accounts: [ChainModel.Id: AccountId],
        sortedChains: [ChainModel]
    ) -> [ConsensusBasedAccountModel.ChainAccount] {
        sortedChains.compactMap { chain in
            guard
                !chain.isEthereumBased,
                chain.parentId != nil,
                let accountId = accounts[chain.chainId] else {
                return nil
            }

            return ConsensusBasedAccountModel.ChainAccount(
                accountId: accountId,
                chain: chain
            )
        }
    }

    static func extractEvmAccounts(
        _ accounts: [ChainModel.Id: AccountId],
        sortedChains: [ChainModel]
    ) -> [ConsensusBasedAccountModel.ChainAccount] {
        sortedChains.compactMap { chain in
            guard
                chain.isEthereumBased,
                let accountId = accounts[chain.chainId] else {
                return nil
            }

            return ConsensusBasedAccountModel.ChainAccount(
                accountId: accountId,
                chain: chain
            )
        }
    }

    static func extractSolochainsAccounts(
        _ accounts: [ChainModel.Id: AccountId],
        sortedChains: [ChainModel],
        consensusIds: Set<ChainModel.Id>
    ) -> [ConsensusBasedAccountModel.ChainAccount] {
        sortedChains.compactMap { chain in
            guard
                !chain.isEthereumBased,
                !consensusIds.contains(chain.chainId),
                chain.parentId == nil,
                let accountId = accounts[chain.chainId] else {
                return nil
            }

            return ConsensusBasedAccountModel.ChainAccount(
                accountId: accountId,
                chain: chain
            )
        }
    }
}
