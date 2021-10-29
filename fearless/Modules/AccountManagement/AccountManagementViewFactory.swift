import Foundation
import SoraFoundation
import RobinHood
import FearlessUtils
import IrohaCrypto
import SoraKeystore

final class AccountManagementViewFactory: AccountManagementViewFactoryProtocol {
    static func createView(for wallet: MetaAccountModel) -> AccountManagementViewProtocol? {
        let wireframe = AccountManagementWireframe()

        let view = AccountManagementViewController(nib: R.nib.accountManagementViewController)

        let iconGenerator = PolkadotIconGenerator()
        let viewModelFactory = ChainAccountViewModelFactory(iconGenerator: iconGenerator)

        let presenter = AccountManagementPresenter(
            viewModelFactory: viewModelFactory,
            logger: Logger.shared
        )

        let chainRepository = SubstrateRepositoryFactory().createChainRepository()

        let interactor = AccountManagementInteractor(
            chainRepository: chainRepository,
            operationQueue: OperationQueue(),
            wallet: wallet,
            logger: Logger.shared
        )

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
