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
            path.value.components.compactMap { component in
                guard component.delegationValue.delaysCallExecution() else { return nil }

                return component.delegationValue.metaId
            }
        }

        guard let delayedWalletId = delayedWalletIds.first else {
            return nil
        }

        return allWallets.first { $0.metaId == delayedWalletId }
    }
}
