import Foundation
import Foundation_iOS

enum SubtensorUnstakeSetupViewFactory {
    static func createView(
        for state: SubtensorSharedStateProtocol,
        netuid: UInt16
    ) -> SubtensorUnstakeSetupViewProtocol? {
        guard let services = SubtensorFlowServicesFactory.createServices(for: state) else {
            return nil
        }

        let chainAsset = state.stakingOption.chainAsset
        let interactor = SubtensorUnstakeSetupInteractor(flowServices: services, state: state, logger: Logger.shared)
        let wireframe = SubtensorSetupWireframe(state: state)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: services.currencyManager)
        let localizationManager = LocalizationManager.shared

        let dataValidationFactory = SubtensorValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let viewModelFactory = SubtensorUnstakeSetupViewModelFactory(
            chainAsset: chainAsset,
            balanceViewModelFactory: BalanceViewModelFactory(
                targetAssetInfo: chainAsset.assetDisplayInfo,
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
            quoteViewModelFactory: SubtensorQuoteViewModelFactory(
                chainAsset: chainAsset,
                priceAssetInfoFactory: priceAssetInfoFactory
            )
        )

        let presenter = SubtensorUnstakeSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            netuid: netuid,
            chainAsset: chainAsset,
            selectedAccount: services.account,
            slippage: state.earnServices.earnSettings.slippageTolerance,
            dataValidationFactory: dataValidationFactory,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = SubtensorUnstakeSetupViewController(
            presenter: presenter,
            isRoot: netuid == SubtensorPallet.rootNetuid,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidationFactory.view = view

        return view
    }
}
