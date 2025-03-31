import Foundation
import SoraFoundation

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

        let hookFactories: [OffRampHookFactoryProtocol] = [
            MercuryoOffRampHookFactory(logger: logger),
            TransakOffRampHookFactory(logger: logger)
        ]

        let interactor = RampInteractor(
            wallet: wallet,
            chainAsset: chainAsset,
            hookFactories: hookFactories,
            eventCenter: EventCenter.shared,
            action: action,
            logger: logger
        )

        let presenter = RampPresenter(
            wireframe: wireframe,
            interactor: interactor,
            action: action
        )

        view.presenter = presenter
        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
