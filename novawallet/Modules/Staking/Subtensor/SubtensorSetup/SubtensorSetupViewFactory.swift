import Foundation
import Foundation_iOS

enum SubtensorSetupViewFactory {
    static func createRootDetailsView(
        for state: SubtensorSharedStateProtocol,
        browseState: SubtensorSubnetBrowseState = .init(),
        presentation: SubtensorRootEntryPresentation = .standard
    ) -> SubtensorSetupViewProtocol? {
        createView(for: state, mode: .rootDetails, browseState: browseState, rootEntryPresentation: presentation)
    }

    static func createSubnetView(
        for state: SubtensorSharedStateProtocol,
        target: SubtensorStakeTarget,
        validator: SubtensorValidatorDirectoryItem?,
        browseState: SubtensorSubnetBrowseState
    ) -> SubtensorSetupViewProtocol? {
        guard !target.isRoot else {
            return nil
        }

        return createView(for: state, mode: .subnetPick(target: target, validator: validator), browseState: browseState)
    }

    static func createQuickPickView(
        for state: SubtensorSharedStateProtocol,
        order: SubtensorQuickPickOrder
    ) -> SubtensorSetupViewProtocol? {
        guard order != .root else { return nil }
        return createView(
            for: state,
            mode: .quickPick(order),
            browseState: SubtensorSubnetBrowseState(order: order),
            quickPickVisit: SubtensorQuickPickVisit(order: order)
        )
    }

    static func createAddStakeView(
        for state: SubtensorSharedStateProtocol,
        position: SubtensorPosition
    ) -> SubtensorSetupViewProtocol? {
        guard position.netuid == SubtensorPallet.rootNetuid else {
            return nil
        }

        return createView(for: state, mode: .addStake(position: position))
    }

    static func createBuyMoreView(
        for state: SubtensorSharedStateProtocol,
        position: SubtensorPosition
    ) -> SubtensorSetupViewProtocol? {
        guard position.netuid != SubtensorPallet.rootNetuid else {
            return nil
        }

        return createView(for: state, mode: .buyMore(position: position))
    }
}

private extension SubtensorSetupViewFactory {
    static func createView(
        for state: SubtensorSharedStateProtocol,
        mode: SubtensorSetupMode,
        browseState: SubtensorSubnetBrowseState = .init(),
        quickPickVisit: SubtensorQuickPickVisit? = nil,
        rootEntryPresentation: SubtensorRootEntryPresentation = .standard
    ) -> SubtensorSetupViewProtocol? {
        guard let services = SubtensorFlowServicesFactory.createServices(for: state) else {
            return nil
        }

        let chainAsset = state.stakingOption.chainAsset
        let interactor = SubtensorSetupInteractor(
            flowServices: services, state: state,
            blockTimeOperationFactory: BlockTimeOperationFactory(chain: chainAsset.chain), logger: Logger.shared
        )
        let wireframe = SubtensorSetupWireframe(state: state)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: services.currencyManager)
        let localizationManager = LocalizationManager.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let dataValidationFactory = SubtensorValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let viewModelFactory = SubtensorSetupViewModelFactory(
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            quoteViewModelFactory: SubtensorQuoteViewModelFactory(
                chainAsset: chainAsset,
                priceAssetInfoFactory: priceAssetInfoFactory
            )
        )

        let presenter = SubtensorSetupPresenter(
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

        let view = SubtensorSetupViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        interactor.presenter = presenter
        dataValidationFactory.view = view

        return view
    }
}
