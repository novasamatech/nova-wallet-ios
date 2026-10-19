import Foundation

extension SubtensorUnstakeSetupPresenter: SubtensorUnstakeSetupPresenterProtocol {
    func setup() {
        provideAmountInputViewModel()
        provideAssetViewModel()
        provideViewModel()

        interactor.setup()
        interactor.loadExistentialDeposit()

        guard !isRoot else {
            return
        }

        interactor.loadSubnetsInfo(for: netuid)

        interactor.loadCatalogue()
        interactor.loadSubnetLogos()
        interactor.loadNovaFeeRate()
        interactor.loadCostBasis(for: netuid)
    }

    func didAppear() {
        guard isConfirmationShown else {
            return
        }

        isConfirmationShown = false
        forceQuoteRefresh()
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
        guard !isRoot, let novaFeeRate = quoteFlow.freshQuote?.novaFeeRate ?? novaFeeRate else {
            return
        }

        let subnetName = SubtensorSubnetNaming.titleWithSymbol(for: netuid, in: catalogue, locale: selectedLocale)

        wireframe.showSubtensorInfo(.swapRate(.sell, subnetName: subnetName, novaFeeRate: novaFeeRate), from: view)
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

        if amount != requestedAmount() {
            provideAmountInputViewModel()
        }

        let dependencies = createValidationDependencies(amount: amount)
        let model = createConfirmModel(for: dependencies)

        dataValidationFactory.validateUnstake(for: dependencies, locale: selectedLocale) { [weak self] in
            guard let self else {
                return
            }

            view?.didStopLoading()

            guard var model else {
                return
            }

            model.acknowledgedQuote = acknowledgedQuote(for: dependencies.quoteContext)
            isConfirmationShown = true
            wireframe.showConfirmation(from: view, model: model)
        }
    }
}

extension SubtensorUnstakeSetupPresenter {
    func createValidationDependencies(amount: Balance) -> SubtensorUnstakeValidatingDependencies {
        let plan = plan(for: amount)
        let positions = Dictionary((basis?.positions ?? []).map { ($0.hotkey, $0.alpha) }) { first, _ in first }

        return SubtensorUnstakeValidatingDependencies(
            netuid: netuid,
            accountId: selectedAccount.chainAccount.accountId,
            hotkey: group?.primaryHotkey,
            amount: amount,
            positionAlpha: plan?.amount ?? maxAmount,
            positions: positions,
            plan: plan,
            groupHotkeys: groupHotkeys,
            availability: group?.availability,
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
            onGroupHotkeysRefresh: { [weak self] in
                self?.loadGroupHotkeys()
            },
            onUnstakeAll: createUnstakeAllOffer(),
            quoteContext: createQuoteContext()
        )
    }

    func createUnstakeAllOffer() -> (() -> Void)? {
        guard let basis, basis.canExitAll else {
            return nil
        }

        return { [weak self] in
            self?.selectMax()
        }
    }

    func createConfirmModel(for dependencies: SubtensorUnstakeValidatingDependencies) -> SubtensorConfirmModel? {
        guard
            let target,
            let group,
            let plan = dependencies.plan,
            let groupHotkeys = dependencies.groupHotkeys,
            let address = try? group.primaryHotkey.toAddress(using: chainAsset.chain.chainFormat) else {
            return nil
        }

        return SubtensorConfirmModel(
            origin: isRoot ? .unstake : .sell,
            account: selectedAccount,
            target: target,
            validator: SubtensorConfirmValidator(
                hotkey: group.primaryHotkey,
                display: DisplayAddress(address: address, username: validatorItem?.name ?? ""),
                annualRate: nil
            ),
            mode: .unstake(SubtensorUnstakeModel(
                netuid: netuid,
                plan: plan,
                groupHotkeys: groupHotkeys
            )),
            tolerance: isRoot ? nil : slippage,
            acknowledgedQuote: acknowledgedQuote(for: dependencies.quoteContext)
        )
    }
}
