import Foundation
import Foundation_iOS

struct SelectRampProviderViewFactory {
    static func createView(
        providerType: RampActionType,
        rampActions: [RampAction],
        chainAsset: ChainAsset,
        delegate: RampDelegate
    ) -> SelectRampProviderViewProtocol? {
        let interactor = SelectRampProviderInteractor(
            rampActions: rampActions
        )
        let wireframe = SelectRampProviderWireframe(
            delegate: delegate,
            chainAsset: chainAsset
        )

        let localizationManager = LocalizationManager.shared

        let presenter = SelectRampProviderPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: SelectRampProviderViewModelFactory(),
            localizationManager: localizationManager,
            assetSymbol: chainAsset.asset.symbol,
            providerType: providerType
        )

        let view = SelectRampProviderViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
