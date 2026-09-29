import Foundation
import Foundation_iOS

enum SubtensorStakingSetupViewFactory {
    static func createRootDetailsView(
        for state: SubtensorStakingSharedStateProtocol
    ) -> SubtensorStakingSetupViewProtocol? {
        createView(for: state, mode: .rootDetails)
    }

    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        initialPosition: SubtensorStakingPosition?
    ) -> SubtensorStakingSetupViewProtocol? {
        guard let initialPosition else {
            return createRootDetailsView(for: state)
        }

        return createView(for: state, mode: .mode(for: initialPosition))
    }
}

private extension SubtensorStakingSetupViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        mode: SubtensorStakingSetupMode
    ) -> SubtensorStakingSetupViewProtocol? {
        guard let services = SubtensorFlowServicesFactory.createServices(for: state) else {
            return nil
        }

        let chainAsset = state.stakingOption.chainAsset
        let interactor = createInteractor(for: state, services: services)
        let wireframe = SubtensorStakingSetupWireframe(state: state)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: services.currencyManager)
        let localizationManager = LocalizationManager.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let dataValidationFactory = SubtensorStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let viewModelFactory = SubtensorStakingSetupViewModelFactory(
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            quoteViewModelFactory: SubtensorQuoteViewModelFactory(
                chainAsset: chainAsset,
                priceAssetInfoFactory: priceAssetInfoFactory
            )
        )

        let presenter = SubtensorStakingSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            mode: mode,
            chainAsset: chainAsset,
            selectedAccount: services.account,
            slippage: state.earnServices.earnSettings.slippageTolerance,
            dataValidationFactory: dataValidationFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = SubtensorStakingSetupViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidationFactory.view = view

        return view
    }

    static func createInteractor(
        for state: SubtensorStakingSharedStateProtocol,
        services: SubtensorFlowServices
    ) -> SubtensorStakingSetupInteractor {
        let earnServices = state.earnServices

        let presetFactory = SubtensorValidatorPresetFactory(
            directoryService: earnServices.validatorDirectoryService,
            recommendationService: earnServices.recommendationService,
            operationQueue: services.operationQueue,
            logger: Logger.shared
        )

        return SubtensorStakingSetupInteractor(
            flowServices: services,
            chainAsset: state.stakingOption.chainAsset,
            presetFactory: presetFactory,
            yieldService: earnServices.yieldService,
            catalogueService: earnServices.catalogueService,
            subnetsService: state.subnetsService,
            earnSettings: earnServices.earnSettings,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            logger: Logger.shared
        )
    }
}
