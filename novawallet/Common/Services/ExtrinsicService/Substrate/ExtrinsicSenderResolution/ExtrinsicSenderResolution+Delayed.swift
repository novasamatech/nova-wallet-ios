import Foundation

extension ExtrinsicSenderResolution {
    func firstDelayedCallWallet() -> MetaAccountModel? {
        switch self {
        case .current:
            nil
        case let .delegate(resolvedDelegate):
            resolvedDelegate.firstDelayedCallWallet()
        }
    }

    func delayedCallExecution() -> Bool {
        firstDelayedCallWallet() != nil
    }
}

extension ExtrinsicSenderResolution.ResolvedDelegate {
    func firstDelayedCallWallet() -> MetaAccountModel? {
        let delayedWalletIds: [MetaAccountModel.Id] = paths.flatMap { path in
            let components = path.value.components

            return components.enumerated().compactMap { indexedComponent in
                let index = indexedComponent.offset
                let component = indexedComponent.element
                if component.delegationValue.delaysCallExecution() {
                    return index == 0 ? delegatedAccount.metaId : components[index - 1].account.metaId
                } else {
                    return nil
                }
            }
        }

        guard let delayedWalletId = delayedWalletIds.first else {
            return nil
        }

        return allWallets.first { $0.metaId == delayedWalletId }
    }
}
