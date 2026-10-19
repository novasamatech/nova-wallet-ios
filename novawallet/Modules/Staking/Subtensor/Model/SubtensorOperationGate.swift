import Foundation

enum SubtensorOperationGate {
    enum Verdict: Equatable {
        case allowed
        case noSigning
        case signerNotSupported(NoSigningSupportType)
    }

    static func verdict(for walletType: MetaAccountModelType) -> Verdict {
        switch walletType {
        case .secrets, .paritySigner, .polkadotVault, .multisig:
            return .allowed
        case .ledger, .genericLedger:
            return .signerNotSupported(.ledger)
        case .proxied:
            return .signerNotSupported(.proxy)
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
        guard wallet.isDelegated() else {
            proceedOnVerdict(for: wallet.type, from: view, onAllowed: onAllowed)
            return
        }

        FeatureSupportChecker(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            userStorageFacade: UserDataStorageFacade.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        ).checkImmediateExecutionSupport(for: wallet, chain: chain) { [weak self] isSupported in
            guard isSupported else {
                self?.presentSignerNotSupported(.multisig, from: view)
                return
            }

            self?.proceedOnVerdict(for: wallet.type, from: view, onAllowed: onAllowed)
        }
    }

    private func proceedOnVerdict(
        for walletType: MetaAccountModelType,
        from view: ControllerBackedProtocol?,
        onAllowed: () -> Void
    ) {
        guard case let .signerNotSupported(type) = SubtensorOperationGate.verdict(for: walletType) else {
            onAllowed()
            return
        }

        presentSignerNotSupported(type, from: view)
    }

    private func presentSignerNotSupported(_ type: NoSigningSupportType, from view: ControllerBackedProtocol?) {
        guard let view else {
            return
        }

        presentSignerNotSupportedView(from: view, type: type) {}
    }
}
