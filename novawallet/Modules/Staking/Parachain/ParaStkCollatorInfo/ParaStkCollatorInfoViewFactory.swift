import Foundation

struct ParaStkCollatorInfoViewFactory {
    static func createView(
        for state: ParachainStakingSharedState,
        collatorInfo: CollatorSelectionInfo
    ) -> ParaStkCollatorInfoViewProtocol? {
        guard let chainAsset = state.settings.value else {
            return nil
        }

        let interactor = ParaStkCollatorInfoInteractor(
            chainAsset: chainAsset,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared
        )

        let wireframe = ParaStkCollatorInfoWireframe()

        let presenter = ParaStkCollatorInfoPresenter(interactor: interactor, wireframe: wireframe)

        let view = ParaStkCollatorInfoViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
