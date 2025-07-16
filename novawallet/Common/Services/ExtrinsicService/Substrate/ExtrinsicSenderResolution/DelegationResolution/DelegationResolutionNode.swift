import Foundation

extension DelegationResolution {
    struct DelegationKey: Hashable {
        let delegate: AccountId
        let delegated: AccountId
    }
}

protocol DelegationResolutionNodeProtocol {
    func pathDelegationValue() -> AccountDelegationPathValue?

    func toNestedValue(
        for callPath: CallCodingPath,
        at overallDepth: UInt
    ) -> DelegationResolutionNodeProtocol?

    func merging(other: DelegationResolutionNodeProtocol) -> DelegationResolutionNodeProtocol
}

protocol DelegationResolutionNodeSourceProtocol {
    func extractDelegationResolutionNode(
        for chain: ChainModel
    ) -> (DelegationResolution.DelegationKey, DelegationResolutionNodeProtocol)?
}

// MARK: - Proxy Node

extension DelegationResolution.Graph {
    final class ProxyResolutionNode: DelegationResolutionNodeProtocol {
        let proxyTypes: Set<Proxy.ProxyType>

        init(proxyTypes: Set<Proxy.ProxyType>) {
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

            return availableTypes.isEmpty ? nil : ProxyResolutionNode(proxyTypes: availableTypes)
        }

        func pathDelegationValue() -> AccountDelegationPathValue? {
            guard let proxyType = proxyTypes.first else { return nil }

            return DelegationResolution.PathFinder.ProxyDelegationValue(proxyType: proxyType)
        }

        func merging(other: DelegationResolutionNodeProtocol) -> DelegationResolutionNodeProtocol {
            guard let otherProxyNode = other as? ProxyResolutionNode else {
                return self
            }

            return ProxyResolutionNode(proxyTypes: proxyTypes.union(otherProxyNode.proxyTypes))
        }
    }
}

// MARK: - Multisig Node

extension DelegationResolution.Graph {
    final class MultisigResolutionNode: DelegationResolutionNodeProtocol {
        let threshold: UInt16
        let signatories: [AccountId]

        init(
            threshold: UInt16,
            signatories: [AccountId]
        ) {
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
                threshold: threshold,
                signatories: signatories
            )
        }

        func merging(
            other _: DelegationResolutionNodeProtocol
        ) -> DelegationResolutionNodeProtocol {
            self
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
                delegate: proxy.accountId,
                delegated: proxiedChainAccount.accountId
            )
            let value = DelegationResolution.Graph.ProxyResolutionNode(proxyTypes: [proxy.type])

            return (key, value)
        } else if
            type == .multisig,
            let multisig = getMultisig(for: chain) {
            let allSignatories = multisig.otherSignatories + [multisig.signatory]

            let key = DelegationResolution.DelegationKey(
                delegate: multisig.signatory,
                delegated: multisig.accountId
            )
            let value = DelegationResolution.Graph.MultisigResolutionNode(
                threshold: UInt16(multisig.threshold),
                signatories: allSignatories
            )

            return (key, value)
        }

        return nil
    }
}
