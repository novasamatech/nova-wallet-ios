import Foundation

extension ManagedMetaAccountModel {
    func renew() -> ManagedMetaAccountModel? {
        switch info.type {
        case .proxied:
            return renewProxy()
        case .multisig:
            return renewMultisig()
        case .secrets, .watchOnly, .genericLedger, .ledger, .paritySigner, .polkadotVault:
            return nil
        }
    }

    func markAsRevoked() -> ManagedMetaAccountModel? {
        switch info.type {
        case .proxied:
            return markProxyAsRevoked()
        case .multisig:
            return markMultisigAsRevoked()
        case .secrets, .watchOnly, .genericLedger, .ledger, .paritySigner, .polkadotVault:
            return nil
        }
    }
}

// MARK: Multisig

private extension ManagedMetaAccountModel {
    func renewMultisig() -> ManagedMetaAccountModel? {
        guard
            let multisig = info.multisigAccount?.anyChainMultisig,
            multisig.isRevoked
        else {
            return nil
        }

        return replacingInfo(info.replacingDelegatedAccountStatus(from: .revoked, to: .new))
    }

    func markMultisigAsRevoked() -> ManagedMetaAccountModel? {
        guard
            let multisig = info.multisigAccount?.anyChainMultisig,
            multisig.isNotRevoked
        else {
            return nil
        }

        return replacingInfo(info.replacingDelegatedAccountStatus(from: multisig.status, to: .revoked))
    }
}

// MARK: Proxy

private extension ManagedMetaAccountModel {
    func renewProxy() -> ManagedMetaAccountModel? {
        guard
            let proxyAccount = info.proxyChainAccount(),
            let proxy = proxyAccount.proxy,
            proxy.isRevoked
        else {
            return nil
        }

        return updateProxyStatus(newStatus: .new, proxy: proxy, chainId: proxyAccount.chainId)
    }

    func markProxyAsRevoked() -> ManagedMetaAccountModel? {
        guard
            let proxyAccount = info.proxyChainAccount(),
            let proxy = proxyAccount.proxy,
            proxy.isNotRevoked
        else {
            return nil
        }

        return updateProxyStatus(
            newStatus: .revoked,
            proxy: proxy,
            chainId: proxyAccount.chainId
        )
    }

    func updateProxyStatus(
        newStatus: DelegatedAccount.Status,
        proxy: DelegatedAccount.ProxyAccountModel,
        chainId: ChainModel.Id
    ) -> ManagedMetaAccountModel {
        let updatedProxy = proxy.replacingStatus(newStatus)

        let newInfo = info.replacingProxy(
            chainId: chainId,
            proxy: updatedProxy
        )

        return replacingInfo(newInfo)
    }
}
