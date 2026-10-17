import Foundation

private extension SubtensorUnstakeSetupPresenter {
    func seedCatalogue() {
        guard !isRoot, let catalogue = interactor.cachedCatalogue().value, catalogue.subnet(for: netuid) != nil else {
            return
        }

        self.catalogue = catalogue
    }

    func seedCostBasis() {
        guard !isRoot, let costBasis = interactor.cachedCostBasis(netuid: netuid).value else {
            return
        }

        self.costBasis = .resolved(costBasis)
    }
}

extension SubtensorUnstakeSetupPresenter: SubtensorUnstakeSetupPresenterProtocol {
    func setup() {
        seedCatalogue()
        seedCostBasis()

        provideAmountInputViewModel()
        provideAssetViewModel()
        provideViewModel()

        interactor.setup()

        guard !isRoot else {
            return
        }

        interactor.loadSubnetsInfo()

        interactor.loadCatalogue()
        interactor.loadSubnetLogos()
        interactor.loadCostBasis(for: netuid)
    }

    func showValidatorInfo() {
        guard let primary = group?.primaryHotkey, let target else {
            return
        }

        wireframe.showValidatorInfo(
            from: view,
            target: target,
            hotkey: primary,
            detail: validatorItem
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
            holdRemainingBlocks(for: amount) == nil else {
            return
        }

        let dependencies = createValidationDependencies(amount: amount)
        let model = createConfirmModel(for: dependencies)

        dataValidationFactory.validateUnstake(for: dependencies, locale: selectedLocale) { [weak self] in
            guard let self, let model else {
                return
            }

            wireframe.showConfirmation(from: view, model: model)
        }
    }
}

extension SubtensorUnstakeSetupPresenter {
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

    func createConfirmModel(for dependencies: SubtensorUnstakeValidatingDep) -> SubtensorConfirmModel? {
        guard
            let target,
            let primary = group?.primaryHotkey,
            let amount = dependencies.amount, amount > 0,
            let address = try? primary.toAddress(using: chainAsset.chain.chainFormat) else {
            return nil
        }

        return SubtensorConfirmModel(
            origin: isRoot ? .unstake : .sell,
            account: selectedAccount,
            target: target,
            validator: SubtensorConfirmValidator(
                hotkey: primary,
                display: DisplayAddress(address: address, username: validatorItem?.name ?? ""),
                annualRate: nil
            ),
            mode: .unstake(SubtensorUnstakeModel(
                hotkey: primary,
                netuid: netuid,
                amount: amount,
                exitHotkeys: dependencies.exitHotkeys
            )),
            tolerance: isRoot ? nil : slippage,
            acknowledgedQuote: dependencies.quoteContext?.latestQuote
        )
    }
}
