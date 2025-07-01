import Foundation
import Operation_iOS

struct MultisigOperationConfirmViewFactory {
    static func createView(for operation: Multisig.PendingOperation) -> MultisigOperationConfirmViewProtocol? {
        guard let interactor = createInteractor(for: operation) else {
            return nil
        }

        let wireframe = MultisigOperationConfirmWireframe()

        let presenter = MultisigOperationConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let view = MultisigOperationConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for operation: Multisig.PendingOperation
    ) -> MultisigOperationConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let multisignWallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let signatoryRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createAccountRepository(for: operation.signatory)

        return MultisigOperationConfirmInteractor(
            operation: operation,
            multisigWallet: multisignWallet,
            signatorWalletRepository: signatoryRepository,
            chainRegistry: chainRegistry,
            callWeightEstimator: CallWeightEstimatingFactory()
        )
    }
}
