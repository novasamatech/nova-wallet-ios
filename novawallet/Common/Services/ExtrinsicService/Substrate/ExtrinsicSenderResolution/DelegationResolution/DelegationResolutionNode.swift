import Foundation

extension DelegationResolution {
    struct DelegationKey: Hashable {
        let delegateAccountId: AccountId
        let delegatedAccountId: AccountId
        let relationType: DelegationClass
    }
}

protocol DelegationResolutionNodeProtocol {
    var metaId: MetaAccountModel.Id { get }

    func pathDelegationValue() -> AccountDelegationPathValue?

    func toNestedValue(
        for callPath: CallCodingPath,
        at overallDepth: UInt
    ) -> DelegationResolutionNodeProtocol?

    func merging(other: DelegationResolutionNodeProtocol) -> DelegationResolutionNodeProtocol

    func delaysCallExecution() -> Bool
}

protocol DelegationResolutionNodeSourceProtocol {
    func extractDelegationResolutionNode(
        for chain: ChainModel
    ) -> (DelegationResolution.DelegationKey, DelegationResolutionNodeProtocol)?
}

// MARK: - Proxy Node

extension DelegationResolution.Graph {
    final class ProxyResolutionNode: DelegationResolutionNodeProtocol {
        let metaId: MetaAccountModel.Id
        let proxyTypes: Set<Proxy.ProxyType>

        init(
            metaId: MetaAccountModel.Id,
            proxyTypes: Set<Proxy.ProxyType>
        ) {
            self.metaId = metaId
            self.proxyTypes = proxyTypes
        }

        func toNestedValue(
            for callPath: CallCodingPath,
            at overallDepth: UInt
        ) -> DelegationResolutionNodeProtocol? {
            let possibleTypes: Set<Proxy.ProxyType> = if overallDepth == 0 {
                ProxyCallFilter.getProxyTypes(for: callPath)
            } else {
                [.any, .nonTransfer]
            }

            let availableTypes = proxyTypes.intersection(possibleTypes)

            return availableTypes.isEmpty ? nil : ProxyResolutionNode(
                metaId: metaId,
                proxyTypes: availableTypes
            )
        }

        func pathDelegationValue() -> AccountDelegationPathValue? {
            guard let proxyType = proxyTypes.first else { return nil }

            return DelegationResolution.PathFinder.ProxyDelegationValue(
                metaId: metaId,
                proxyType: proxyType
            )
        }

        func merging(other: DelegationResolutionNodeProtocol) -> DelegationResolutionNodeProtocol {
            guard let otherProxyNode = other as? ProxyResolutionNode else {
                return self
            }

            return ProxyResolutionNode(
                metaId: other.metaId,
                proxyTypes: proxyTypes.union(otherProxyNode.proxyTypes)
            )
        }

        func delaysCallExecution() -> Bool {
            false
        }
    }
}

// MARK: - Multisig Node

extension DelegationResolution.Graph {
    final class MultisigResolutionNode: DelegationResolutionNodeProtocol {
        let metaId: MetaAccountModel.Id
        let threshold: UInt16
        let signatories: [AccountId]

        init(
            metaId: MetaAccountModel.Id,
            threshold: UInt16,
            signatories: [AccountId]
        ) {
            self.metaId = metaId
            self.threshold = threshold
            self.signatories = signatories
        }

        func toNestedValue(
            for _: CallCodingPath,
            at _: UInt
        ) -> DelegationResolutionNodeProtocol? {
            self
        }

        func pathDelegationValue() -> AccountDelegationPathValue? {
            DelegationResolution.PathFinder.MultisigDelegationValue(
                metaId: metaId,
                threshold: threshold,
                signatories: signatories
            )
        }

        func merging(
            other _: DelegationResolutionNodeProtocol
        ) -> DelegationResolutionNodeProtocol {
            self
        }

        func delaysCallExecution() -> Bool {
            threshold > 1
        }
    }
}

// MARK: - Helper

extension MetaAccountModel: DelegationResolutionNodeSourceProtocol {
    func extractDelegationResolutionNode(
        for chain: ChainModel
    ) -> (DelegationResolution.DelegationKey, DelegationResolutionNodeProtocol)? {
        if
            type == .proxied,
            let proxiedChainAccount = proxyChainAccount(chainId: chain.chainId),
            let proxy = proxiedChainAccount.proxy {
            let key = DelegationResolution.DelegationKey(
                delegateAccountId: proxy.accountId,
                delegatedAccountId: proxiedChainAccount.accountId,
                relationType: .proxy
            )
            let value = DelegationResolution.Graph.ProxyResolutionNode(
                metaId: metaId,
                proxyTypes: [proxy.type]
            )

            return (key, value)
        } else if
            type == .multisig,
            let multisig = getMultisig(for: chain) {
            let allSignatories = multisig.otherSignatories + [multisig.signatory]

            let key = DelegationResolution.DelegationKey(
                delegateAccountId: multisig.signatory,
                delegatedAccountId: multisig.accountId,
                relationType: .multisig
            )

            let value = DelegationResolution.Graph.MultisigResolutionNode(
                metaId: metaId,
                threshold: UInt16(multisig.threshold),
                signatories: allSignatories
            )

            return (key, value)
        }

        return nil
    }
}
