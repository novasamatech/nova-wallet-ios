import Foundation
import Foundation_iOS

struct PayRootViewFactory {
    static func createView() -> ScrollViewHostAndDecoratorControlling? {
        let interactor = PayRootInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            shopRequiredChainId: RaiseModel.chainId,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let presenter = PayRootPresenter(interactor: interactor)

        let view = PayRootViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
