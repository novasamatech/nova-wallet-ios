import Foundation

struct MythosStkUnstakeSetupViewFactory {
    static func createView(
        for state: MythosStakingSharedStateProtocol
    ) -> MythosStkUnstakeSetupViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: state,
                chainAsset: chainAsset,
                currencyManager: currencyManager
            ) else {
            return nil
        }

        let wireframe = MythosStkUnstakeSetupWireframe()

        let presenter = MythosStkUnstakeSetupPresenter(interactor: interactor, wireframe: wireframe)

        let view = MythosStkUnstakeSetupViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for _: MythosStakingSharedStateProtocol,
        chainAsset _: ChainAsset,
        currencyManager _: CurrencyManagerProtocol
    ) -> MythosStkUnstakeSetupInteractor? {
        nil
    }
}
