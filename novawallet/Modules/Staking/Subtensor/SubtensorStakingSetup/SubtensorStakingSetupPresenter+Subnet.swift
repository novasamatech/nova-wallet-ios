import Foundation

extension SubtensorStakingSetupPresenter {
    func loadSubnetDataIfNeeded() {
        guard let netuid = mode.netuid else {
            return
        }

        if !mode.isRootLane, !isSubnetDataRequested {
            isSubnetDataRequested = true

            loadCatalogue()
            loadRankingView()
            interactor.loadSubnetLogos()
        }

        loadYieldsIfNeeded(for: netuid)
    }

    func loadCatalogue() {
        if let catalogue = interactor.cachedCatalogue().value {
            self.catalogue = catalogue
        }

        interactor.loadCatalogue()
    }

    func loadRankingView() {
        let cachedRankingView = interactor.cachedRankingView()

        if let rankingView = cachedRankingView.value {
            self.rankingView = rankingView
            hasExpiredRankingSeed = !cachedRankingView.isFresh
        }

        interactor.loadRankingView()
    }

    func loadYieldsIfNeeded(for netuid: UInt16) {
        guard yieldsNetuid != netuid else {
            return
        }

        yieldsNetuid = netuid
        yields = interactor.cachedYields(netuid: netuid).value

        interactor.loadYields(netuid: netuid)
    }

    func loadCostBasisIfNeeded(for netuid: UInt16) {
        if let cachedCostBasis = interactor.cachedCostBasis(netuid: netuid).value {
            costBasis = .resolved(cachedCostBasis)
        }

        interactor.loadCostBasis(for: netuid)
    }

    func validatorAnnualRate() -> Decimal? {
        guard
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

    func matchingRankedSubnet() -> SubtensorRankedSubnet? {
        // Only positive, non-carried ages can be inverted: backend clamps negative ages to zero.
        guard let subnetRef, let rankingView,
              !rankingView.generation.carriedOverNetuids.contains(subnetRef.netuid),
              let subnet = rankingView.items.first(where: { $0.netuid == subnetRef.netuid }),
              let age = subnet.ageBlocks, age > 0,
              age <= rankingView.generation.sourceBlockNumber,
              rankingView.generation.sourceBlockNumber - age == subnetRef.registeredAt else {
            return nil
        }

        return subnet
    }

    func createViewModelInput() -> SubtensorStakingSetupViewModelInput {
        let subnetData = SubtensorSetupSubnetData(
            catalogue: catalogue,
            subnetLogos: subnetLogos,
            rankedSubnet: matchingRankedSubnet(),
            annualRate: validatorAnnualRate(),
            isQuoteFailed: isQuoteFailed,
            costBasis: costBasis,
            blockTime: blockTime
        )

        return SubtensorStakingSetupViewModelInput(
            mode: mode,
            target: target,
            subnetData: subnetData,
            transferable: transferable,
            maxAmount: maxAmount,
            amount: inputAmount(),
            validator: validatorState,
            fee: fee,
            price: price,
            quote: quoteFlow.freshQuote,
            positionStake: positionStake(),
            quickPickOrder: quickPickVisit?.order,
            selectionFailed: quickPickVisit?.error != nil,
            presetError: presetError,
            rootEntryPresentation: rootEntryPresentation
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
            detail: validatorItem
        )
    }

    func selectCardHeader() {
        if case .rootDetails = mode {
            wireframe.showRootDetails(from: view, browseState: browseState)
            return
        }

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

            refreshFee()
            updateQuote()
            provideViewModel()
        }
    }

    func showSwapRateInfo() {
        guard !mode.isRootLane, let netuid = mode.netuid else {
            return
        }

        let subnetName = SubtensorSubnetNaming.titleWithSymbol(
            for: netuid,
            in: createViewModelInput().matchingCatalogue,
            locale: selectedLocale
        )

        wireframe.showSubtensorInfo(.swapRate(.buy, subnetName: subnetName), from: view)
    }

    func showAvgBuyPriceInfo() {
        guard case let .buyMore(position) = mode else {
            return
        }

        let matchingCatalogue = createViewModelInput().matchingCatalogue
        let sheet = SubtensorInfoSheet.avgBuyPrice(
            symbol: SubtensorSubnetNaming.symbol(for: position.netuid, in: matchingCatalogue),
            subnetName: SubtensorSubnetNaming.titleWithSymbol(
                for: position.netuid, in: matchingCatalogue, locale: selectedLocale
            )
        )

        wireframe.showSubtensorInfo(sheet, from: view)
    }
}
