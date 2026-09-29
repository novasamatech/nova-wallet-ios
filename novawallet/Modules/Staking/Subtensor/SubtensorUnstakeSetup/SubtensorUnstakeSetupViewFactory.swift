import Foundation
import Foundation_iOS

enum SubtensorUnstakeSetupViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        netuid: UInt16
    ) -> SubtensorUnstakeSetupViewProtocol? {
        guard let services = SubtensorFlowServicesFactory.createServices(for: state) else {
            return nil
        }

        let chainAsset = state.stakingOption.chainAsset
        let interactor = createInteractor(for: state, services: services)
        let wireframe = SubtensorUnstakeSetupWireframe(state: state)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: services.currencyManager)
        let localizationManager = LocalizationManager.shared

        let dataValidationFactory = SubtensorStakingValidationFactory(
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

        let view = SubtensorUnstakeSetupVC(
            presenter: presenter,
            isRoot: netuid == SubtensorStakingPallet.rootNetuid,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidationFactory.view = view

        return view
    }
}

private extension SubtensorUnstakeSetupViewFactory {
    static func createInteractor(
        for state: SubtensorStakingSharedStateProtocol,
        services: SubtensorFlowServices
    ) -> SubtensorUnstakeSetupInteractor {
        let earnServices = state.earnServices

        let validatorFactory = SubtensorValidatorPresetFactory(
            directoryService: earnServices.validatorDirectoryService,
            recommendationService: earnServices.recommendationService,
            operationQueue: services.operationQueue,
            logger: Logger.shared
        )

        return SubtensorUnstakeSetupInteractor(
            flowServices: services,
            chainAsset: state.stakingOption.chainAsset,
            subnetsService: state.subnetsService,
            catalogueService: earnServices.catalogueService,
            earnConfigProvider: earnServices.earnConfigProvider,
            validatorFactory: validatorFactory,
            rootHoldFactory: earnServices.rootHoldFactory,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            logger: Logger.shared
        )
    }
}
