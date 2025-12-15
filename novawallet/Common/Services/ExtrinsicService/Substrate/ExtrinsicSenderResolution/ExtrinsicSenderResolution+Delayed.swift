import Foundation

struct DelayedCallWallets {
    let delayed: MetaAccountModel
    let delaying: MetaAccountModel
}

extension ExtrinsicSenderResolution {
    func firstDelayedCallWallets() -> DelayedCallWallets? {
        switch self {
        case .current:
            nil
        case let .delegate(resolvedDelegate):
            resolvedDelegate.firstDelayedCallWallets()
        }
    }

    func delayedCallExecution() -> Bool {
        firstDelayedCallWallets() != nil
    }
}

extension ExtrinsicSenderResolution.ResolvedDelegate {
    func firstDelayedCallWallets() -> DelayedCallWallets? {
        let delayedWalletIds: [(MetaAccountModel.Id, MetaAccountModel.Id?)] = paths.flatMap { path in
            let components = path.value.components

            return components.enumerated().compactMap { indexedComponent in
                let index = indexedComponent.offset
                let component = indexedComponent.element

                return if component.delegationValue.delaysCallExecution() {
                    index == 0
                        ? (delegatedAccount.metaId, delegateAccount?.metaId)
                        : (components[index - 1].account.metaId, component.account.metaId)
                } else {
                    nil
                }
            }
        }

        guard
            let delayedWalletsPair = delayedWalletIds.first,
            let delayedWallet = allWallets.first(where: { $0.metaId == delayedWalletsPair.0 }),
            let delayingWallet = allWallets.first(where: { $0.metaId == delayedWalletsPair.1 })
        else {
            return nil
        }

        return DelayedCallWallets(
            delayed: delayedWallet,
            delaying: delayingWallet
        )
    }
}
