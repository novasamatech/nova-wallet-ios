import Foundation
import Foundation_iOS

enum SubtensorStakingSetupViewFactory {
    static func createRootDetailsView(
        for state: SubtensorStakingSharedStateProtocol,
        browseState: SubtensorSubnetBrowseState = .init(),
        presentation: SubtensorRootEntryPresentation = .standard
    ) -> SubtensorStakingSetupViewProtocol? {
        createView(for: state, mode: .rootDetails, browseState: browseState, rootEntryPresentation: presentation)
    }

    static func createSubnetView(
        for state: SubtensorStakingSharedStateProtocol,
        target: SubtensorStakeTarget,
        validator: SubtensorValidatorDirectoryItem?,
        browseState: SubtensorSubnetBrowseState = .init()
    ) -> SubtensorStakingSetupViewProtocol? {
        guard !target.isRoot else {
            return nil
        }

        return createView(for: state, mode: .subnetPick(target: target, validator: validator), browseState: browseState)
    }

    static func createQuickPickView(
        for state: SubtensorStakingSharedStateProtocol,
        order: SubtensorQuickPickOrder
    ) -> SubtensorStakingSetupViewProtocol? {
        createView(
            for: state,
            mode: .quickPick(order),
            browseState: SubtensorSubnetBrowseState(order: order),
            quickPickVisit: SubtensorQuickPickVisit(order: order)
        )
    }

    static func createAddStakeView(
        for state: SubtensorStakingSharedStateProtocol,
        position: SubtensorStakingPosition
    ) -> SubtensorStakingSetupViewProtocol? {
        guard position.netuid == SubtensorStakingPallet.rootNetuid else {
            return nil
        }

        return createView(for: state, mode: .addStake(position: position))
    }

    static func createBuyMoreView(
        for state: SubtensorStakingSharedStateProtocol,
        position: SubtensorStakingPosition
    ) -> SubtensorStakingSetupViewProtocol? {
        guard position.netuid != SubtensorStakingPallet.rootNetuid else {
            return nil
        }

        return createView(for: state, mode: .buyMore(position: position))
    }
}

private extension SubtensorStakingSetupViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        mode: SubtensorStakingSetupMode,
        browseState: SubtensorSubnetBrowseState = .init(),
        quickPickVisit: SubtensorQuickPickVisit? = nil,
        rootEntryPresentation: SubtensorRootEntryPresentation = .standard
    ) -> SubtensorStakingSetupViewProtocol? {
        guard let services = SubtensorFlowServicesFactory.createServices(for: state) else {
            return nil
        }

        let chainAsset = state.stakingOption.chainAsset
        let interactor = SubtensorStakingSetupInteractor(flowServices: services, state: state, logger: Logger.shared)
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
            logger: Logger.shared,
            browseState: browseState,
            quickPickVisit: quickPickVisit,
            rootEntryPresentation: rootEntryPresentation
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
}
