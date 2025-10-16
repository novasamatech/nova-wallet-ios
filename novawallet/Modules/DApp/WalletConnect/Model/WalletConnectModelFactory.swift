import Foundation
import WalletConnectSign

struct WalletConnectChainsResolution {
    let resolved: [Blockchain: ChainModel]
    let unresolved: Set<String>

    init(resolved: [Blockchain: ChainModel] = [:], unresolved: Set<String> = []) {
        self.resolved = resolved
        self.unresolved = unresolved
    }

    func adding(chain: ChainModel, blockchain: Blockchain) -> WalletConnectChainsResolution {
        var newResolved = resolved
        newResolved[blockchain] = chain

        return .init(resolved: newResolved, unresolved: unresolved)
    }

    func adding(unresolvedId: String) -> WalletConnectChainsResolution {
        let newUnresolved = unresolved.union([unresolvedId])
        return .init(resolved: resolved, unresolved: newUnresolved)
    }

    func merging(with resolution: WalletConnectChainsResolution) -> WalletConnectChainsResolution {
        let newResolved = resolved.merging(resolution.resolved) { value1, _ in
            value1
        }

        let newUnresolved = unresolved.union(resolution.unresolved)

        return .init(resolved: newResolved, unresolved: newUnresolved)
    }
}

struct WalletConnectProposalResolution {
    let requiredNamespaces: WalletConnectChainsResolution
    let optionalNamespaces: WalletConnectChainsResolution?

    func allResolvedChains() -> WalletConnectChainsResolution {
        if let optionalNamespaces = optionalNamespaces {
            return requiredNamespaces.merging(with: optionalNamespaces)
        } else {
            return requiredNamespaces
        }
    }
}

enum WalletConnectModelFactory {
    private static func createSessionNamespaces(
        using proposalNamespaces: [String: ProposalNamespace],
        wallet: MetaAccountModel,
        resolvedChains: [Blockchain: ChainModel]
    ) -> [String: SessionNamespace] {
        proposalNamespaces.reduce(into: [:]) { accum, keyValue in
            let namespaceId = keyValue.key
            let proposalNamespace = keyValue.value

            let accounts: [Account]? = proposalNamespace.chains?.compactMap { blockchain in
                guard
                    let chain = resolvedChains[blockchain],
                    let account = wallet.fetch(for: chain.accountRequest()),
                    let address = account.toAddress() else {
                    return nil
                }

                return Account(blockchain: blockchain, address: address)
            }

            let blockchains = accounts?.map(\.blockchain)

            let sessionNamespace = SessionNamespace(
                chains: blockchains,
                accounts: accounts ?? [],
                methods: proposalNamespace.methods,
                events: proposalNamespace.events
            )

            accum[namespaceId] = sessionNamespace
        }
    }

    private static func resolveChains(
        from blockchains: [Blockchain],
        chainsStore: ChainsStoreProtocol
    ) -> WalletConnectChainsResolution {
        let knownChainIds = chainsStore.availableChainIds()

        return blockchains.reduce(WalletConnectChainsResolution()) { result, blockchain in
            do {
                let caip2ChainId = try Caip2.ChainId(raw: blockchain.absoluteString)

                let optChainId = knownChainIds.first { chainId in
                    guard let chain = chainsStore.getChain(for: chainId) else {
                        return false
                    }

                    return caip2ChainId.match(chain)
                }

                if
                    let chainId = optChainId,
                    let chain = chainsStore.getChain(for: chainId) {
                    return result.adding(chain: chain, blockchain: blockchain)
                } else {
                    return result.adding(unresolvedId: blockchain.absoluteString)
                }

            } catch {
                return result.adding(unresolvedId: blockchain.absoluteString)
            }
        }
    }
}

extension WalletConnectModelFactory {
    static func createSessionNamespaces(
        from proposal: Session.Proposal,
        wallet: MetaAccountModel,
        resolvedChains: [Blockchain: ChainModel]
    ) -> [String: SessionNamespace] {
        let requiredNamespaces = createSessionNamespaces(
            using: proposal.requiredNamespaces,
            wallet: wallet,
            resolvedChains: resolvedChains
        )

        let optionalNamespaces = createSessionNamespaces(
            using: proposal.optionalNamespaces ?? [:],
            wallet: wallet,
            resolvedChains: resolvedChains
        )

        return requiredNamespaces.merging(optionalNamespaces) { namespace1, namespace2 in
            let blockchains: Set<Blockchain>?

            if namespace1.chains != nil || namespace2.chains != nil {
                blockchains = Set(namespace1.chains ?? []).union(Set(namespace2.chains ?? []))
            } else {
                blockchains = nil
            }

            return SessionNamespace(
                chains: blockchains.map { Array($0) },
                accounts: Array(Set(namespace1.accounts).union(Set(namespace2.accounts))),
                methods: namespace1.methods.union(namespace2.methods),
                events: namespace1.events.union(namespace2.events)
            )
        }
    }

    static func createChainsResolution(
        from proposalNamespaces: [String: ProposalNamespace],
        chainsStore: ChainsStoreProtocol
    ) -> WalletConnectChainsResolution {
        proposalNamespaces.values.reduce(WalletConnectChainsResolution()) { accum, namespace in
            guard let chains = namespace.chains else {
                return accum
            }

            let newResolution = resolveChains(from: chains, chainsStore: chainsStore)

            return accum.merging(with: newResolution)
        }
    }

    static func createProposalResolution(
        from proposal: Session.Proposal,
        chainsStore: ChainsStoreProtocol
    ) -> WalletConnectProposalResolution {
        let requiredNamespaces = createChainsResolution(
            from: proposal.requiredNamespaces,
            chainsStore: chainsStore
        )

        let optionalNamespaces = proposal.optionalNamespaces.map {
            createChainsResolution(from: $0, chainsStore: chainsStore)
        }

        return .init(requiredNamespaces: requiredNamespaces, optionalNamespaces: optionalNamespaces)
    }

    static func createSessionChainsResolution(
        from session: Session,
        chainsStore: ChainsStoreProtocol
    ) -> WalletConnectChainsResolution {
        session.namespaces.values.reduce(WalletConnectChainsResolution()) { result, namespace in
            let resolution = resolveChains(from: namespace.chains ?? [], chainsStore: chainsStore)
            return result.merging(with: resolution)
        }
    }

    static func resolveChain(for blockchain: Blockchain, chainsStore: ChainsStoreProtocol) -> ChainModel? {
        let resolution = resolveChains(from: [blockchain], chainsStore: chainsStore)
        return resolution.resolved.first?.value
    }
}
