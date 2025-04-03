import Foundation
import Foundation_iOS

struct SelectRampProviderViewFactory {
    static func createView(
        providerType: RampActionType,
        rampActions: [RampAction],
        assetSymbol: AssetModel.Symbol,
        delegate: RampDelegate
    ) -> SelectRampProviderViewProtocol? {
        let interactor = SelectRampProviderInteractor(
            rampActions: rampActions
        )
        let wireframe = SelectRampProviderWireframe(delegate: delegate)

        let localizationManager = LocalizationManager.shared

        let presenter = SelectRampProviderPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: SelectRampProviderViewModelFactory(),
            localizationManager: localizationManager,
            assetSymbol: assetSymbol,
            providerType: providerType
        )

        let view = SelectRampProviderViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
