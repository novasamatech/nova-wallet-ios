import Foundation

extension SubtensorStakingSetupPresenter {
    func loadSubnetDataIfNeeded() {
        guard !mode.isRootLane else {
            return
        }

        if !isSubnetDataRequested {
            isSubnetDataRequested = true

            loadCatalogueIfNeeded()
            loadRankingViewIfNeeded()
            interactor.loadSubnetLogos()
        }

        loadYieldsIfNeeded(for: mode.netuid)
    }

    func loadCatalogueIfNeeded() {
        let cachedCatalogue = interactor.cachedCatalogue()

        if let catalogue = cachedCatalogue.value {
            self.catalogue = catalogue
            isCatalogueLoaded = true
            hasExpiredCatalogueSeed = !cachedCatalogue.isFresh
        }

        if !cachedCatalogue.isFresh {
            interactor.loadCatalogue()
        }
    }

    func loadRankingViewIfNeeded() {
        let cachedRankingView = interactor.cachedRankingView()

        if let rankingView = cachedRankingView.value {
            self.rankingView = rankingView
            hasExpiredRankingSeed = !cachedRankingView.isFresh
        }

        if !cachedRankingView.isFresh {
            interactor.loadRankingView()
        }
    }

    func loadYieldsIfNeeded(for netuid: UInt16) {
        guard yieldsNetuid != netuid else {
            return
        }

        let cachedYields = interactor.cachedYields(netuid: netuid)

        yieldsNetuid = netuid
        yields = cachedYields.value
        isYieldsLoaded = cachedYields.value != nil

        if !cachedYields.isFresh {
            interactor.loadYields(netuid: netuid)
        }
    }

    func loadRootYieldIfNeeded() {
        guard mode.isRootLane, !isRootRateRequested else {
            return
        }

        isRootRateRequested = true

        let cachedRootYield = interactor.cachedRootYield()

        if let yield = cachedRootYield.value {
            rootRate = SubtensorAlphaApyFormatter.annualRate(from: yield)
            isRootRateLoaded = true
        }

        if !cachedRootYield.isFresh {
            interactor.loadRootYield()
        }
    }

    func loadCostBasisIfNeeded(for netuid: UInt16) {
        if case let .fresh(cachedCostBasis, _) = interactor.cachedCostBasis(netuid: netuid) {
            costBasis = .resolved(cachedCostBasis)
        } else {
            interactor.loadCostBasis(for: netuid)
        }
    }

    func subnetAnnualRate() -> Decimal? {
        guard
            !mode.isRootLane,
            let hotkey = validatorState.validator?.hotkey,
            yields?.netuid == mode.netuid else {
            return nil
        }

        return SubtensorAlphaApyFormatter.annualRate(for: hotkey, in: yields)
    }

    func positionStake() -> Balance? {
        guard case let .addStake(position) = mode, let positionsState else {
            return nil
        }

        return positionsState.positions.first {
            $0.netuid == position.netuid && $0.hotkey == position.hotkey
        }?.stakeAlpha
    }

    func holdRemaining() -> TimeInterval? {
        guard
            case .addStake = mode,
            let preflight,
            preflight.rootStakeUnlockInterval > 0,
            let lastStakeBlock = preflight.lastStakeBlock,
            let currentBlock else {
            return nil
        }

        let hold = SubtensorRootHold(interval: preflight.rootStakeUnlockInterval, lastStakeBlock: lastStakeBlock)
        let remainingBlocks = hold.remainingBlocks(at: UInt64(currentBlock))

        guard remainingBlocks > 0 else {
            return nil
        }

        return (TimeInterval(remainingBlocks) * TimeInterval(SubtensorStakingFlowConstants.blockTimeMillis)).seconds
    }

    func createViewModelInput() -> SubtensorStakingSetupViewModelInput {
        let subnetData = SubtensorSetupSubnetData(
            catalogue: catalogue,
            isCatalogueLoaded: isCatalogueLoaded,
            subnetLogos: subnetLogos,
            rankedSubnet: rankingView?.items.first { $0.netuid == mode.netuid },
            annualRate: subnetAnnualRate(),
            isYieldsLoaded: isYieldsLoaded,
            isQuoteFailed: isQuoteFailed,
            costBasis: costBasis
        )

        return SubtensorStakingSetupViewModelInput(
            mode: mode,
            target: target,
            subnetData: subnetData,
            transferable: transferable,
            maxAmount: maxAmount,
            amount: inputAmount(),
            validator: validatorState,
            rootRate: rootRate,
            isRootRateLoaded: isRootRateLoaded,
            fee: fee,
            price: price,
            quote: quoteFlow.freshQuote,
            positionStake: positionStake(),
            holdRemaining: holdRemaining()
        )
    }

    func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(for: createViewModelInput(), locale: selectedLocale)

        view?.didReceive(viewModel: viewModel)
    }

    func showLockedValidatorInfo() {
        guard let hotkey = mode.lockedHotkey else {
            return
        }

        wireframe.showValidatorInfo(
            from: view,
            target: .root,
            hotkey: hotkey,
            detail: validatorItem.map { SubtensorValidatorDetail(item: $0, identity: nil) }
        )
    }

    func selectCardHeader() {
        guard
            case .subnetPick = mode,
            let target,
            let subnetRef,
            let subnet = catalogue?.subnet(for: subnetRef) else {
            return
        }

        wireframe.showSubnetDetails(
            from: view,
            input: SubtensorSubnetDetailsInput(subnet: subnet, target: target, validator: validatorItem),
            delegate: self
        )
    }

    func chooseMyself() {
        guard case .subnetPick = mode else {
            return
        }

        wireframe.showSubnetSelection(from: view, delegate: self)
    }

    func selectSettings() {
        guard mode.hasSettings else {
            return
        }

        wireframe.showSlippageSettings(from: view, current: slippage) { [weak self] newValue in
            guard let self else {
                return
            }

            slippage = newValue
            interactor.saveSlippage(newValue)

            refreshFee(resetting: false)
            updateQuote()
            provideViewModel()
        }
    }

    func showSwapRateInfo() {
        guard !mode.isRootLane else {
            return
        }

        let subnetName = SubtensorSubnetNaming.titleWithSymbol(
            for: mode.netuid,
            in: catalogue,
            locale: selectedLocale
        )

        wireframe.showSubtensorInfo(.swapRate(.buy, subnetName: subnetName), from: view)
    }

    func showAvgBuyPriceInfo() {
        guard case .buyMore = mode else {
            return
        }

        let sheet = SubtensorInfoSheet.avgBuyPrice(
            symbol: SubtensorSubnetNaming.symbol(for: mode.netuid, in: catalogue),
            subnetName: SubtensorSubnetNaming.titleWithSymbol(for: mode.netuid, in: catalogue, locale: selectedLocale)
        )

        wireframe.showSubtensorInfo(sheet, from: view)
    }
}
