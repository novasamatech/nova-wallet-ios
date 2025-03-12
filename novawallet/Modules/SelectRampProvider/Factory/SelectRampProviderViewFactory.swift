import Foundation
import SoraFoundation

struct SelectRampProviderViewFactory {
    static func createView(
        providerType: SelectRampProvider.ProviderType,
        rampActions: [RampAction],
        assetSymbol: AssetModel.Symbol
    ) -> SelectRampProviderViewProtocol? {
        let interactor = SelectRampProviderInteractor(
            rampActions: rampActions
        )
        let wireframe = SelectRampProviderWireframe()

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
