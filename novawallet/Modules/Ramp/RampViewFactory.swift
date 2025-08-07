import Foundation

final class RampViewFactory {
    static func createView(
        for action: RampAction,
        chainAsset: ChainAsset,
        delegate: RampDelegate?
    ) -> RampViewProtocol? {
        guard let wallet = SelectedWalletSettings.shared.value else { return nil }

        let logger = Logger.shared

        let view = RampViewController()
        let wireframe = RampWireframe(delegate: delegate)

        let rampProvider = RampAggregator.defaultAggregator()
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let interactor = RampInteractor(
            wallet: wallet,
            chainAsset: chainAsset,
            rampProvider: rampProvider,
            eventCenter: EventCenter.shared,
            action: action,
            operationQueue: operationQueue,
            logger: logger
        )

        let presenter = RampPresenter(
            wireframe: wireframe,
            interactor: interactor,
            chainAsset: chainAsset
        )

        view.presenter = presenter
        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
