import Foundation

enum SubtensorOperationGate {
    enum Verdict: Equatable {
        case allowed
        case noSigning
        case signerNotSupported(NoSigningSupportType)
    }

    static func verdict(for walletType: MetaAccountModelType) -> Verdict {
        switch walletType {
        case .secrets, .paritySigner, .polkadotVault, .proxied, .multisig:
            return .allowed
        case .ledger, .genericLedger:
            return .signerNotSupported(.ledger)
        case .watchOnly:
            return .noSigning
        }
    }
}

protocol SubtensorOperationGating: MessageSheetPresentable {}

extension SubtensorOperationGating {
    func checkingSubtensorSigning(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        from view: ControllerBackedProtocol?,
        onAllowed: @escaping () -> Void
    ) {
        if case let .signerNotSupported(type) = SubtensorOperationGate.verdict(for: wallet.type) {
            presentSignerNotSupported(type, from: view)
            return
        }

        guard wallet.isDelegated() else {
            onAllowed()
            return
        }

        let delayedType: NoSigningSupportType = wallet.type == .multisig ? .multisig : .proxy

        FeatureSupportChecker(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            userStorageFacade: UserDataStorageFacade.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        ).checkImmediateExecutionSupport(for: wallet, chain: chain) { [weak self] isSupported in
            guard isSupported else {
                self?.presentSignerNotSupported(delayedType, from: view)
                return
            }

            onAllowed()
        }
    }

    private func presentSignerNotSupported(_ type: NoSigningSupportType, from view: ControllerBackedProtocol?) {
        guard let view else {
            return
        }

        presentSignerNotSupportedView(from: view, type: type) {}
    }
}
