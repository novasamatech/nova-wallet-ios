import Foundation

private extension SubtensorUnstakeSetupPresenter {
    func seedCatalogue() -> HTTPCachePeek<SubtensorSubnetCatalogue> {
        guard !isRoot else {
            return .miss
        }

        let cachedCatalogue = interactor.cachedCatalogue()

        guard let catalogue = cachedCatalogue.value, catalogue.subnet(for: netuid) != nil else {
            return .miss
        }

        self.catalogue = catalogue

        return cachedCatalogue
    }

    func seedCostBasis() -> HTTPCachePeek<SubtensorCostBasis> {
        guard !isRoot else {
            return .miss
        }

        let cachedCostBasis = interactor.cachedCostBasis(netuid: netuid)

        if case let .fresh(costBasis, _) = cachedCostBasis {
            self.costBasis = .resolved(costBasis)
        }

        return cachedCostBasis
    }
}

extension SubtensorUnstakeSetupPresenter: SubtensorUnstakeSetupPresenterProtocol {
    func setup() {
        let cachedCatalogue = seedCatalogue()
        let cachedCostBasis = seedCostBasis()

        provideAmountInputViewModel()
        provideAssetViewModel()
        provideViewModel()

        interactor.setup()

        guard !isRoot else {
            return
        }

        interactor.loadSubnetsInfo(forcingRefresh: false)

        if !cachedCatalogue.isFresh {
            interactor.loadCatalogue()
        }

        interactor.loadSubnetLogos()

        if !cachedCostBasis.isFresh {
            interactor.loadCostBasis(for: netuid)
        }
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { .absolute($0) }

        applyInputChange()
    }

    func selectMax() {
        inputResult = .rate(1)

        provideAmountInputViewModel()
        applyInputChange()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAmountInputViewModel()
        applyInputChange()
    }

    func showValidatorInfo() {
        guard let primary = group?.primaryHotkey, let target else {
            return
        }

        wireframe.showValidatorInfo(
            from: view,
            target: target,
            hotkey: primary,
            detail: validatorItem.map { SubtensorValidatorDetail(item: $0, identity: nil) }
        )
    }

    func showSwapRateInfo() {
        guard !isRoot else {
            return
        }

        let subnetName = SubtensorSubnetNaming.titleWithSymbol(for: netuid, in: catalogue, locale: selectedLocale)

        wireframe.showSubtensorInfo(.swapRate(.sell, subnetName: subnetName), from: view)
    }

    func showAvgBuyPriceInfo() {
        guard !isRoot else {
            return
        }

        let sheet = SubtensorInfoSheet.avgBuyPrice(
            symbol: SubtensorSubnetNaming.symbol(for: netuid, in: catalogue),
            subnetName: SubtensorSubnetNaming.titleWithSymbol(for: netuid, in: catalogue, locale: selectedLocale)
        )

        wireframe.showSubtensorInfo(sheet, from: view)
    }

    func proceed() {
        let amount = inputAmount()

        guard
            let amount, amount > 0,
            let basis, basis.available > 0,
            target != nil,
            holdRemaining(for: amount) == nil else {
            return
        }

        let dependencies = createValidationDependencies(amount: amount)
        let model = createConfirmModel(for: dependencies)

        validateUnstake(
            for: dependencies,
            dataValidationFactory: dataValidationFactory,
            selectedLocale: selectedLocale
        ) { [weak self] in
            guard let self, let model else {
                return
            }

            wireframe.showConfirm(from: view, model: model)
        }
    }
}

extension SubtensorUnstakeSetupPresenter: SubtensorUnstakePresenterValidating {
    func createValidationDependencies(amount: Balance) -> SubtensorUnstakeValidatingDep {
        let exitHotkeys = exitHotkeys(for: amount)
        let basis = basis

        return SubtensorUnstakeValidatingDep(
            netuid: netuid,
            accountId: selectedAccount.chainAccount.accountId,
            amount: amount,
            positionAlpha: exitHotkeys != nil ? basis?.total : basis?.primaryAlpha,
            availability: group?.availability,
            exitHotkeys: exitHotkeys,
            balance: balance,
            fee: fee,
            existentialDeposit: existentialDeposit,
            preflight: preflight,
            holds: holds,
            currentBlock: currentBlock,
            blockTime: SubtensorStakingFlowConstants.blockTimeMillis,
            assetDisplayInfo: inputDisplayInfo,
            syncFailed: isPositionsSyncFailed,
            onFeeRefresh: { [weak self] in
                self?.refreshFee()
            },
            onPreflightRefresh: { [weak self] in
                self?.refreshPreflight()
            },
            onPositionsRefresh: { [weak self] in
                self?.interactor.refreshPositions()
            },
            onUnstakeAll: createUnstakeAllOffer(),
            quoteContext: createQuoteContext()
        )
    }

    func createUnstakeAllOffer() -> (() -> Void)? {
        guard let basis, basis.canExitAll, remainingHoldBlocks(for: basis.hotkeys) == nil else {
            return nil
        }

        return { [weak self] in
            self?.selectMax()
        }
    }

    func createQuoteContext() -> SubtensorQuoteValidatingContext? {
        guard !isRoot else {
            return nil
        }

        let latestQuote = quoteFlow.freshQuote

        return SubtensorQuoteValidatingContext(
            latestQuote: latestQuote,
            acknowledgedLimit: latestQuote?.limitPrice,
            tradesUnavailable: tradesUnavailable,
            onQuoteRefresh: { [weak self] in
                self?.forceQuoteRefresh()
            }
        )
    }

    func createConfirmModel(for dependencies: SubtensorUnstakeValidatingDep) -> SubtensorUnstakeConfirmModel? {
        guard
            let target,
            let primary = group?.primaryHotkey,
            let amount = dependencies.amount, amount > 0,
            let address = try? primary.toAddress(using: chainAsset.chain.chainFormat) else {
            return nil
        }

        return SubtensorUnstakeConfirmModel(
            origin: isRoot ? .unstake : .sell,
            account: selectedAccount,
            target: target,
            validator: SubtensorConfirmValidator(
                hotkey: primary,
                display: DisplayAddress(address: address, username: validatorItem?.name ?? ""),
                annualRate: nil
            ),
            unstakeModel: SubtensorUnstakeModel(
                hotkey: primary,
                netuid: netuid,
                amount: amount,
                exitHotkeys: dependencies.exitHotkeys
            ),
            tolerance: isRoot ? nil : slippage,
            acknowledgedQuote: dependencies.quoteContext?.latestQuote
        )
    }
}
