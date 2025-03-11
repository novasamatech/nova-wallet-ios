import Foundation
import SoraFoundation

struct SelectRampProviderViewFactory {
    static func createView(
        providerType: SelectRampProvider.ProviderType,
        chainAsset: ChainAsset,
        accountId: AccountId
    ) -> SelectRampProviderViewProtocol? {
        let provider = switch providerType {
        case .onramp:
            PurchaseAggregator.defaultAggregator()
        case .offramp:
            PurchaseAggregator.defaultAggregator()
        }

        let interactor = SelectRampProviderInteractor(
            rampProvider: provider,
            chainAsset: chainAsset,
            accountId: accountId
        )
        let wireframe = SelectRampProviderWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = SelectRampProviderPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: SelectRampProviderViewModelFactory(),
            localizationManager: localizationManager,
            chainAsset: chainAsset,
            providerType: providerType
        )

        let view = SelectRampProviderViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
