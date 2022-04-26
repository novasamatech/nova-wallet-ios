import Foundation
import CommonWallet
import BigInt

final class StakingMainPresenter {
    weak var view: StakingMainViewProtocol?
    var wireframe: StakingMainWireframeProtocol!
    var interactor: StakingMainInteractorInputProtocol!

    let networkInfoViewModelFactory: NetworkInfoViewModelFactoryProtocol
    let viewModelFacade: StakingViewModelFacadeProtocol
    let logger: LoggerProtocol?

    let dataValidatingFactory: StakingDataValidatingFactoryProtocol

    private var stateViewModelFactory: StakingStateViewModelFactoryProtocol
    private var stateMachine: StakingStateMachineProtocol

    var chainAsset: ChainAsset? {
        stateMachine.viewState { (state: BaseStakingState) in state.commonData.chainAsset }
    }

    var priceData: PriceData? {
        stateMachine.viewState { (state: BaseStakingState) in state.commonData.price }
    }

    private var balance: Decimal?
    private var networkStakingInfo: NetworkStakingInfo?
    private var accounts: [AccountId: MetaChainAccountResponse] = [:]
    private var nomination: Nomination?

    init(
        stateViewModelFactory: StakingStateViewModelFactoryProtocol,
        networkInfoViewModelFactory: NetworkInfoViewModelFactoryProtocol,
        viewModelFacade: StakingViewModelFacadeProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        logger: LoggerProtocol?
    ) {
        self.stateViewModelFactory = stateViewModelFactory
        self.networkInfoViewModelFactory = networkInfoViewModelFactory
        self.viewModelFacade = viewModelFacade
        self.logger = logger

        let stateMachine = StakingStateMachine()
        self.stateMachine = stateMachine

        self.dataValidatingFactory = dataValidatingFactory

        stateMachine.delegate = self
    }

    private func accountForAddress(_ address: AccountAddress) -> MetaChainAccountResponse? {
        let accountId = try? address.toAccountId()

        return accountId.flatMap { accounts[$0] }
    }

    private func provideStakingInfo() {
        let commonData = stateMachine.viewState { (state: BaseStakingState) in state.commonData }

        if let chainAsset = commonData?.chainAsset, let networkStakingInfo = networkStakingInfo {
            let networkStakingInfoViewModel = networkInfoViewModelFactory
                .createNetworkStakingInfoViewModel(
                    with: networkStakingInfo,
                    chainAsset: chainAsset,
                    minNominatorBond: commonData?.minNominatorBond,
                    priceData: commonData?.price
                )
            view?.didRecieveNetworkStakingInfo(viewModel: networkStakingInfoViewModel)
        } else {
            view?.didRecieveNetworkStakingInfo(viewModel: nil)
        }
    }

    private func provideState() {
        let state = stateViewModelFactory.createViewModel(from: stateMachine.state)
        view?.didReceiveStakingState(viewModel: state)
    }

    private func provideMainViewModel() {
        let commonData = stateMachine.viewState { (state: BaseStakingState) in state.commonData }

        guard let address = commonData?.address, let chainAsset = commonData?.chainAsset else {
            return
        }

        let viewModel = networkInfoViewModelFactory.createMainViewModel(
            from: address,
            chainAsset: chainAsset,
            balance: balance ?? 0.0
        )

        view?.didReceive(viewModel: viewModel)
    }

    private func handleStakeMore() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        let stashItem: StashItem? = stateMachine.viewState { (state: BaseStashNextState) in
            state.stashItem
        }

        let stashAccount = stashItem.flatMap { accountForAddress($0.stash) }

        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                stash: stashAccount?.chainAccount,
                for: stashItem?.stash ?? "",
                locale: locale
            )
        ]).runValidation { [weak self] in
            self?.wireframe.showBondMore(from: self?.view)
        }
    }

    private func handleUnstake() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        let stashItem: StashItem? = stateMachine.viewState { (state: BaseStakingState) in
            (state as? StashLedgerStateProtocol)?.stashItem
        }

        let ledgerInfo: StakingLedger? = stateMachine.viewState { (state: BaseStakingState) in
            (state as? StashLedgerStateProtocol)?.ledgerInfo
        }

        let controllerAccount = stashItem.flatMap { accountForAddress($0.controller) }

        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                controller: controllerAccount?.chainAccount,
                for: stashItem?.controller ?? "",
                locale: locale
            ),

            dataValidatingFactory.unbondingsLimitNotReached(
                ledgerInfo?.unlocking.count,
                locale: locale
            )
        ]).runValidation { [weak self] in
            self?.wireframe.showUnbond(from: self?.view)
        }
    }

    private func handlePendingRewards() {
        if let validatorState = stateMachine.viewState(using: { (state: ValidatorState) in state }) {
            let stashAddress = validatorState.stashItem.stash
            wireframe.showRewardPayoutsForValidator(from: view, stashAddress: stashAddress)
            return
        }

        if let stashState = stateMachine.viewState(using: { (state: BaseStashNextState) in state }) {
            let stashAddress = stashState.stashItem.stash
            wireframe.showRewardPayoutsForNominator(from: view, stashAddress: stashAddress)
            return
        }
    }

    private func setupValidators(for bondedState: BondedState) {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        let stashItem = bondedState.stashItem
        let controllerAccount = accountForAddress(stashItem.controller)

        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                controller: controllerAccount?.chainAccount,
                for: stashItem.controller,
                locale: locale
            )
        ]).runValidation { [weak self] in
            guard
                let chainAsset = bondedState.commonData.chainAsset,
                let amount = Decimal.fromSubstrateAmount(
                    bondedState.ledgerInfo.active,
                    precision: Int16(chainAsset.asset.precision)
                ),
                let payee = bondedState.payee,
                let rewardDestination = try? RewardDestination(
                    payee: payee,
                    stashItem: bondedState.stashItem,
                    chainFormat: chainAsset.chain.chainFormat
                ),
                let controllerAccount = controllerAccount,
                controllerAccount.chainAccount.toAddress() == bondedState.stashItem.controller
            else {
                return
            }

            let existingBonding = ExistingBonding(
                stashAddress: bondedState.stashItem.stash,
                controllerAccount: controllerAccount,
                amount: amount,
                rewardDestination: rewardDestination,
                selectedTargets: nil
            )

            self?.wireframe.proceedToSelectValidatorsStart(from: self?.view, existingBonding: existingBonding)
        }
    }

    private func presentRebond() {
        let locale = view?.selectedLocale

        let actions = StakingRebondOption.allCases.map { option -> AlertPresentableAction in
            let title = option.titleForLocale(locale)
            let action = AlertPresentableAction(title: title) { [weak self] in
                self?.wireframe.showRebond(from: self?.view, option: option)
            }
            return action
        }

        let title = R.string.localizable.stakingRebond(preferredLanguages: locale?.rLanguages)
        let closeTitle = R.string.localizable.commonCancel(preferredLanguages: locale?.rLanguages)
        let viewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: actions,
            closeAction: closeTitle
        )

        wireframe.present(viewModel: viewModel, style: .actionSheet, from: view)
    }
}

// MARK: - StakingMainPresenterProtocol

extension StakingMainPresenter: StakingMainPresenterProtocol {
    func setup() {
        provideState()
        provideMainViewModel()
        provideStakingInfo()

        interactor.setup()
    }

    func performAssetSelection() {
        wireframe.showChainAssetSelection(
            from: view,
            selectedChainAssetId: chainAsset?.chainAssetId,
            delegate: self
        )
    }

    func performMainAction() {
        guard let commonData = stateMachine
            .viewState(using: { (state: BaseStakingState) in state })?.commonData else {
            return
        }

        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        let nomination = stateMachine.viewState(
            using: { (state: NominatorState) in state }
        )?.nomination

        DataValidationRunner(validators: [
            dataValidatingFactory.maxNominatorsCountNotApplied(
                counterForNominators: commonData.counterForNominators,
                maxNominatorsCount: commonData.maxNominatorsCount,
                hasExistingNomination: nomination != nil,
                locale: locale
            )
        ]).runValidation { [weak self] in
            self?.wireframe.showSetupAmount(from: self?.view)
        }
    }

    func performAccountAction() {
        wireframe.showAccountsSelection(from: view)
    }

    func performRewardInfoAction() {
        guard let rewardCalculator = stateMachine
            .viewState(using: { (state: BaseStakingState) in state })?.commonData.calculatorEngine else {
            return
        }

        let maxReward = rewardCalculator.calculateMaxReturn(isCompound: true, period: .year)
        let avgReward = rewardCalculator.calculateAvgReturn(isCompound: true, period: .year)

        wireframe.showRewardDetails(from: view, maxReward: maxReward, avgReward: avgReward)
    }

    func performChangeValidatorsAction() {
        wireframe.showNominatorValidators(from: view)
    }

    func performSetupValidatorsForBondedAction() {
        guard let bonded = stateMachine.viewState(using: { (state: BondedState) in state }) else {
            return
        }

        setupValidators(for: bonded)
    }

    func performStakeMoreAction() {
        handleStakeMore()
    }

    func performRedeemAction() {
        guard let view = view else { return }
        let selectedLocale = view.localizationManager?.selectedLocale

        let baseState = stateMachine.viewState(using: { (state: BaseStashNextState) in state })
        let controllerAccount = baseState.flatMap { accountForAddress($0.stashItem.controller) }

        guard controllerAccount != nil else {
            wireframe.presentMissingController(
                from: view,
                address: baseState?.stashItem.controller ?? "",
                locale: selectedLocale
            )
            return
        }

        wireframe.showRedeem(from: view)
    }

    func performRebondAction() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        let baseState = stateMachine.viewState(using: { (state: BaseStashNextState) in state })
        let controllerAccount = baseState.flatMap { accountForAddress($0.stashItem.controller) }

        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                controller: controllerAccount?.chainAccount,
                for: baseState?.stashItem.controller ?? "",
                locale: locale
            )
        ]).runValidation { [weak self] in
            self?.presentRebond()
        }
    }

    func performAnalyticsAction() {
        let isNominator: AnalyticsContainerViewMode = {
            if stateMachine.viewState(using: { (state: ValidatorState) in state }) != nil {
                return .none
            }

            if stateMachine.viewState(using: { (state: BaseStashNextState) in state }) != nil {
                return .accountIsNominator
            }
            return .none
        }()

        let includeValidators: AnalyticsContainerViewMode = {
            if stateMachine.viewState(using: { (state: ValidatorState) in state }) != nil {
                return .none
            }
            return nomination != nil ? .includeValidatorsTab : .none
        }()

        wireframe.showAnalytics(from: view, mode: isNominator.union(includeValidators))
    }

    func networkInfoViewDidChangeExpansion(isExpanded: Bool) {
        interactor.saveNetworkInfoViewExpansion(isExpanded: isExpanded)
    }

    func performManageAction(_ action: StakingManageOption) {
        switch action {
        case .stakeMore:
            handleStakeMore()
        case .unstake:
            handleUnstake()
        case .pendingRewards:
            handlePendingRewards()
        case .rewardDestination:
            wireframe.showRewardDestination(from: view)
        case .changeValidators:
            wireframe.showNominatorValidators(from: view)
        case .setupValidators:
            if let bondedState = stateMachine.viewState(using: { (state: BondedState) in state }) {
                setupValidators(for: bondedState)
            }
        case .controllerAccount:
            wireframe.showControllerAccount(from: view)
        case .yourValidator:
            if let validatorState = stateMachine.viewState(using: { (state: ValidatorState) in state }) {
                let stashAddress = validatorState.stashItem.stash
                wireframe.showYourValidatorInfo(stashAddress, from: view)
            }
        }
    }
}

extension StakingMainPresenter: StakingStateMachineDelegate {
    func stateMachineDidChangeState(_: StakingStateMachineProtocol) {
        provideState()
    }
}

extension StakingMainPresenter: StakingMainInteractorOutputProtocol {
    private func handle(error: Error) {
        let locale = view?.localizationManager?.selectedLocale

        if !wireframe.present(error: error, from: view, locale: locale) {
            logger?.error("Did receive error: \(error)")
        }
    }

    func didReceive(price: PriceData?) {
        stateMachine.state.process(price: price)
        provideStakingInfo()
    }

    func didReceive(priceError: Error) {
        logger?.error("Price fetch failed with error: \(priceError)")
    }

    func didReceive(totalReward: TotalRewardItem) {
        stateMachine.state.process(totalReward: totalReward)
    }

    func didReceive(totalRewardError: Error) {
        logger?.error("Total reward fetch failed with error: \(totalRewardError)")
    }

    func didReceive(accountInfo: AccountInfo?) {
        if let availableValue = accountInfo?.data.available, let chainAsset = chainAsset {
            balance = Decimal.fromSubstrateAmount(
                availableValue,
                precision: Int16(chainAsset.asset.precision)
            )
        } else {
            balance = 0.0
        }

        stateMachine.state.process(accountInfo: accountInfo)

        provideMainViewModel()
    }

    func didReceive(balanceError: Error) {
        handle(error: balanceError)
    }

    func didReceive(selectedAddress: String) {
        stateMachine.state.process(address: selectedAddress)

        provideMainViewModel()
    }

    func didReceive(calculator: RewardCalculatorEngineProtocol) {
        stateMachine.state.process(calculator: calculator)
    }

    func didReceive(calculatorError: Error) {
        handle(error: calculatorError)
    }

    func didReceive(stashItem: StashItem?) {
        stateMachine.state.process(stashItem: stashItem)

        if let stashItem = stashItem {
            logger?.debug("Stash: \(stashItem.stash)")
            logger?.debug("Controller: \(stashItem.controller)")
        } else {
            logger?.debug("No stash found")
        }
    }

    func didReceive(stashItemError: Error) {
        handle(error: stashItemError)
    }

    func didReceive(ledgerInfo: StakingLedger?) {
        stateMachine.state.process(ledgerInfo: ledgerInfo)

        if let ledgerInfo = ledgerInfo {
            logger?.debug("Did receive ledger info: \(ledgerInfo)")
        } else {
            logger?.debug("No ledger info received")
        }
    }

    func didReceive(ledgerInfoError: Error) {
        handle(error: ledgerInfoError)
    }

    func didReceive(nomination: Nomination?) {
        self.nomination = nomination
        stateMachine.state.process(nomination: nomination)

        if let nomination = nomination {
            logger?.debug("Did receive nomination: \(nomination)")
        } else {
            logger?.debug("No nomination received")
        }
    }

    func didReceive(nominationError: Error) {
        handle(error: nominationError)
    }

    func didReceive(validatorPrefs: ValidatorPrefs?) {
        stateMachine.state.process(validatorPrefs: validatorPrefs)

        if let prefs = validatorPrefs {
            logger?.debug("Did receive validator: \(prefs)")
        } else {
            logger?.debug("No validator received")
        }
    }

    func didReceive(validatorError: Error) {
        handle(error: validatorError)
    }

    func didReceive(eraStakersInfo: EraStakersInfo) {
        stateMachine.state.process(eraStakersInfo: eraStakersInfo)

        logger?.debug("Did receive era stakers info: \(eraStakersInfo.activeEra)")
    }

    func didReceive(eraStakersInfoError: Error) {
        handle(error: eraStakersInfoError)
    }

    func didReceive(newChainAsset: ChainAsset) {
        networkStakingInfo = nil

        accounts = [:]

        stateMachine.state.process(chainAsset: newChainAsset)

        provideMainViewModel()
        provideStakingInfo()
    }

    func didReceive(networkStakingInfo: NetworkStakingInfo) {
        self.networkStakingInfo = networkStakingInfo

        let commondData = stateMachine.viewState { (state: BaseStakingState) in state.commonData }
        let minStake = networkStakingInfo.calculateMinimumStake(given: commondData?.minNominatorBond)
        stateMachine.state.process(minStake: minStake)
        provideStakingInfo()
    }

    func didReceive(networkStakingInfoError: Error) {
        handle(error: networkStakingInfoError)
    }

    func didReceive(payee: RewardDestinationArg?) {
        stateMachine.state.process(payee: payee)
    }

    func didReceive(payeeError: Error) {
        handle(error: payeeError)
    }

    func didReceiveAccount(_ account: MetaChainAccountResponse?, for accountId: AccountId) {
        accounts[accountId] = account
    }

    func didReceiveMaxNominatorsPerValidator(result: Result<UInt32, Error>) {
        switch result {
        case let .success(maxNominatorsPerValidator):
            stateMachine.state.process(maxNominatorsPerValidator: maxNominatorsPerValidator)
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceieve(subqueryRewards: Result<[SubqueryRewardItemData]?, Error>, period: AnalyticsPeriod) {
        switch subqueryRewards {
        case let .success(rewards):
            stateMachine.state.process(subqueryRewards: (rewards, period))
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveMinNominatorBond(result: Result<BigUInt?, Error>) {
        switch result {
        case let .success(minNominatorBond):
            stateMachine.state.process(minNominatorBond: minNominatorBond)

            if let networkStakingInfo = networkStakingInfo {
                let minStake = networkStakingInfo.calculateMinimumStake(
                    given: minNominatorBond
                )

                stateMachine.state.process(minStake: minStake)
            }

            provideStakingInfo()

        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveCounterForNominators(result: Result<UInt32?, Error>) {
        switch result {
        case let .success(counterForNominators):
            stateMachine.state.process(counterForNominators: counterForNominators)
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveMaxNominatorsCount(result: Result<UInt32?, Error>) {
        switch result {
        case let .success(maxNominatorsCount):
            stateMachine.state.process(maxNominatorsCount: maxNominatorsCount)
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceive(eraCountdownResult: Result<EraCountdown, Error>) {
        switch eraCountdownResult {
        case let .success(eraCountdown):
            stateMachine.state.process(eraCountdown: eraCountdown)
        case let .failure(error):
            handle(error: error)
        }
    }

    func networkInfoViewExpansion(isExpanded: Bool) {
        view?.expandNetworkInfoView(isExpanded)
    }
}

extension StakingMainPresenter: AssetSelectionDelegate {
    func assetSelection(view _: ChainSelectionViewProtocol, didCompleteWith chainAsset: ChainAsset) {
        interactor.save(chainAsset: chainAsset)
    }
}
