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
            wireframe.showConfirmation(from: view, model: model)
        }
    }
}

extension SubtensorUnstakeSetupPresenter {
    func createValidationDependencies(amount: Balance) -> SubtensorUnstakeValidatingDep {
        let plan = plan(for: amount)
        let basis = basis

        let positionAlpha = plan.map { plan in
            plan.partial.flatMap { basis?.position(of: $0.hotkey) } ?? plan.amount
        } ?? basis?.drawable

        return SubtensorUnstakeValidatingDep(
            netuid: netuid,
            accountId: selectedAccount.chainAccount.accountId,
            hotkey: group?.primaryHotkey,
            amount: amount,
            positionAlpha: positionAlpha,
            plan: plan,
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

    func createConfirmModel(for dependencies: SubtensorUnstakeValidatingDep) -> SubtensorConfirmModel? {
        guard
            let target,
            let group,
            let plan = dependencies.plan,
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
                groupHotkeys: group.positions.map(\.hotkey)
            )),
            tolerance: isRoot ? nil : slippage,
            acknowledgedQuote: acknowledgedQuote(for: dependencies.quoteContext)
        )
    }
}
