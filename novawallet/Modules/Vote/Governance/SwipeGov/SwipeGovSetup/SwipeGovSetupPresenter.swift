import Foundation
import Foundation_iOS
import BigInt

final class SwipeGovSetupPresenter {
    weak var view: SwipeGovSetupViewProtocol?
    private let wireframe: SwipeGovSetupWireframeProtocol
    let interactor: SwipeGovSetupInteractorInputProtocol

    let chain: ChainModel
    let metaAccount: MetaAccountModel

    let observableState: ReferendumsObservableState

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol
    let referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol
    let lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol
    let dataValidatingFactory: GovernanceValidatorFactoryProtocol
    let govBalanceCalculator: AvailableBalanceMapping
    let logger: LoggerProtocol

    private(set) var assetBalance: AssetBalance?
    private(set) var votesResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    private(set) var priceData: PriceData?
    private(set) var blockNumber: BlockNumber?
    private(set) var blockTime: BlockTime?
    private(set) var lockDiff: GovernanceLockStateDiff?

    private(set) var inputResult: AmountInputResult?
    private(set) var conviction: ConvictionVoting.Conviction = .none
    private(set) var initVotingPower: VotingPowerLocal?
    private(set) var referendum: ReferendumLocal?
    private(set) var votingItems: [VotingBasketItemLocal]?

    init(
        chain: ChainModel,
        metaAccount: MetaAccountModel,
        observableState: ReferendumsObservableState,
        initData: ReferendumVotingInitData,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol,
        govBalanceCalculator: AvailableBalanceMapping,
        interactor: SwipeGovSetupInteractorInputProtocol,
        wireframe: SwipeGovSetupWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.chain = chain
        self.metaAccount = metaAccount
        self.observableState = observableState
        votesResult = initData.votesResult
        blockNumber = initData.blockNumber
        blockTime = initData.blockTime
        lockDiff = initData.lockDiff
        referendum = initData.referendum
        initVotingPower = initData.presetVotingPower
        self.dataValidatingFactory = dataValidatingFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        self.referendumStringsViewModelFactory = referendumStringsViewModelFactory
        self.govBalanceCalculator = govBalanceCalculator
        self.lockChangeViewModelFactory = lockChangeViewModelFactory
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger

        self.localizationManager = localizationManager
    }
}

// MARK: SwipeGovSetupPresenterProtocol

extension SwipeGovSetupPresenter: SwipeGovSetupPresenterProtocol {
    func proceed() {
        performValidation { [weak self] in
            guard
                let self,
                let assetInfo = chain.utilityAssetDisplayInfo(),
                let votingPower = deriveVotePower(using: assetInfo)
            else {
                return
            }

            interactor.process(votingPower: votingPower)
        }
    }

    func setup() {
        if let initVotingPower, let assetInfo = chain.utilityAssetDisplayInfo() {
            conviction = ConvictionVoting.Conviction(from: initVotingPower.conviction)
            inputResult = .absolute(initVotingPower.amount.decimal(assetInfo: assetInfo))

            updateAfterAmountChanged()
            provideConviction()
        }

        updateView()

        interactor.setup()
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { .absolute($0) }

        updateAfterAmountChanged()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAmountInputViewModel()

        updateAfterAmountChanged()
    }

    func selectConvictionValue(_ value: UInt) {
        guard let newConviction = ConvictionVoting.Conviction(rawValue: UInt8(value)) else {
            return
        }

        conviction = newConviction

        updateAfterConvictionSelect()
    }

    func reuseGovernanceLock() {
        guard let model = deriveReuseLocks() else {
            return
        }

        inputResult = .absolute(model.governance)

        provideAmountInputViewModel()

        updateAfterAmountChanged()
    }

    func reuseAllLock() {
        guard let model = deriveReuseLocks() else {
            return
        }

        inputResult = .absolute(model.all)

        provideAmountInputViewModel()

        updateAfterAmountChanged()
    }
}

// MARK: SwipeGovSetupInteractorOutputProtocol

extension SwipeGovSetupPresenter: SwipeGovSetupInteractorOutputProtocol {
    func didProcessVotingPower(_ votingPower: VotingPowerLocal) {
        wireframe.showSwipeGov(
            from: view,
            newVotingPower: votingPower,
            locale: selectedLocale
        )
    }

    func didReceiveLockStateDiff(_ diff: GovernanceLockStateDiff) {
        lockDiff = diff

        updateLockedAmountView()
        updateLockedPeriodView()
        provideReuseLocksViewModel()
    }

    func didReceiveAccountVotes(
        _ votes: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>
    ) {
        let updateAndRefreshClosure: () -> Void = {
            self.votesResult = votes
            self.refreshLockDiff()
        }

        guard
            let newVoting = votes.value,
            let votesResult = votesResult?.value,
            newVoting.hasDiff(from: votesResult)
        else {
            if votes.value == nil {
                updateAndRefreshClosure()
            } else {
                votesResult = votes
            }

            return
        }

        updateAndRefreshClosure()
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        self.blockNumber = blockNumber

        interactor.refreshBlockTime()

        updateLockedAmountView()
        updateLockedPeriodView()
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime

        updateLockedAmountView()
        updateLockedPeriodView()
    }

    func didReceiveAssetBalance(_ assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance

        updateAfterBalanceReceive()
    }

    func didReceivePrice(_ price: PriceData?) {
        priceData = price

        updateAmountPriceView()
    }

    func didReceiveBaseError(_ error: SwipeGovSetupInteractorError) {
        logger.error("Did receive base error: \(error)")

        processError(error)
    }
}

// MARK: Private

private extension SwipeGovSetupPresenter {
    func updateView() {
        updateAvailableBalanceView()
        provideAmountInputViewModel()
        updateChainAssetViewModel()
        updateAmountPriceView()
        updateLockedAmountView()
        updateLockedPeriodView()
        provideReuseLocksViewModel()
        updateVotesView()
    }

    func updateVotesView() {
        guard
            let assetInfo = chain.utilityAssetDisplayInfo(),
            let votingAmount = deriveVotePower(using: assetInfo)
        else {
            return
        }

        let voteString = referendumStringsViewModelFactory.createVotes(
            from: votingAmount.votingAmount,
            chain: chain,
            locale: selectedLocale
        )

        view?.didReceiveVotes(viewModel: voteString ?? "")
    }

    func updateAfterAmountChanged() {
        refreshLockDiff()
        updateVotesView()
        updateAmountPriceView()
    }

    func refreshLockDiff() {
        guard
            let referendum,
            let trackVoting = observableState.voting?.value,
            let assetPrecision = chain.utilityAssetDisplayInfo()?.assetPrecision,
            let amount = (inputResult?.absoluteValue(from: balance()) ?? 0).toSubstrateAmount(precision: assetPrecision)
        else {
            return
        }

        let voteAction = ReferendumVoteActionModel(
            amount: amount,
            conviction: conviction
        )
        let newVote = ReferendumNewVote(
            index: referendum.index,
            voteAction: .aye(voteAction)
        )

        interactor.refreshLockDiff(
            for: trackVoting,
            newVotes: [newVote]
        )
    }

    func updateAfterConvictionSelect() {
        updateVotesView()
        refreshLockDiff()
    }

    func updateAfterBalanceReceive() {
        updateAvailableBalanceView()
        updateAmountPriceView()
        provideAmountInputViewModelIfRate()
        provideReuseLocksViewModel()
    }

    func processError(_ error: SwipeGovSetupInteractorError) {
        switch error {
        case .assetBalanceFailed,
             .priceFailed,
             .blockNumberSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .blockTimeFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshBlockTime()
            }
        case .stateDiffFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshLockDiff()
            }
        case let .votingPowerSaveFailed(error):
            wireframe.present(
                error: error,
                from: view,
                locale: selectedLocale
            )
        }
    }

    func performValidation(notifying completionBlock: @escaping DataValidationRunnerCompletion) {
        guard let assetInfo = chain.utilityAssetDisplayInfo() else {
            return
        }

        let votePower = deriveVotePower(using: assetInfo)

        let params = GovernanceVotePowerValidatingParams(
            assetBalance: assetBalance,
            votePower: votePower,
            assetInfo: assetInfo
        )

        DataValidationRunner.validateVotingPower(
            factory: dataValidatingFactory,
            params: params,
            selectedLocale: selectedLocale,
            successClosure: completionBlock
        )
    }

    func deriveVotePower(using assetInfo: AssetBalanceDisplayInfo) -> VotingPowerLocal? {
        guard let amount = inputResult?.absoluteValue(from: balance()).toSubstrateAmount(
            precision: assetInfo.assetPrecision
        ) else {
            return nil
        }

        return VotingPowerLocal(
            chainId: chain.chainId,
            metaId: metaAccount.metaId,
            conviction: .init(from: conviction),
            amount: amount
        )
    }

    func balance() -> Decimal {
        let balanceValue = govBalanceCalculator.availableBalanceElseZero(from: assetBalance)

        guard
            let precision = chain.utilityAsset()?.displayInfo.assetPrecision,
            let balance = Decimal.fromSubstrateAmount(balanceValue, precision: precision) else {
            return 0
        }

        return balance
    }

    private func updateAvailableBalanceView() {
        let availableInPlank = govBalanceCalculator.availableBalanceElseZero(from: assetBalance)

        let precision = chain.utilityAsset()?.displayInfo.assetPrecision ?? 0
        let balanceDecimal = Decimal.fromSubstrateAmount(
            availableInPlank,
            precision: precision
        ) ?? 0

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            balanceDecimal,
            priceData: nil
        ).value(for: selectedLocale).amount

        view?.didReceiveBalance(viewModel: viewModel)
    }

    private func updateChainAssetViewModel() {
        guard let asset = chain.utilityAsset() else {
            return
        }

        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let viewModel = chainAssetViewModelFactory.createViewModel(from: chainAsset)
        view?.didReceiveInputChainAsset(viewModel: viewModel)
    }

    private func updateAmountPriceView() {
        if chain.utilityAsset()?.priceId != nil {
            let inputAmount = inputResult?.absoluteValue(from: balance()) ?? 0

            let priceData = priceData ?? PriceData.zero()

            let price = balanceViewModelFactory.priceFromAmount(
                inputAmount,
                priceData: priceData
            ).value(for: selectedLocale)

            view?.didReceiveAmountInputPrice(viewModel: price)
        } else {
            view?.didReceiveAmountInputPrice(viewModel: nil)
        }
    }

    private func provideAmountInputViewModelIfRate() {
        guard case .rate = inputResult else {
            return
        }

        provideAmountInputViewModel()
    }

    private func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balance())

        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    private func updateLockedAmountView() {
        guard
            let lockDiff = lockDiff,
            let viewModel = lockChangeViewModelFactory.createAmountTransitionAfterVotingViewModel(
                from: lockDiff,
                locale: selectedLocale
            ) else {
            return
        }

        view?.didReceiveLockedAmount(viewModel: viewModel)
    }

    private func updateLockedPeriodView() {
        guard
            let lockDiff = lockDiff,
            let blockNumber = blockNumber,
            let blockTime = blockTime,
            let viewModel = lockChangeViewModelFactory.createPeriodTransitionAfterVotingViewModel(
                from: lockDiff,
                blockNumber: blockNumber,
                blockTime: blockTime,
                locale: selectedLocale
            ) else {
            return
        }

        view?.didReceiveLockedPeriod(viewModel: viewModel)
    }

    func provideConviction() {
        view?.didReceiveConviction(viewModel: UInt(conviction.rawValue))
    }

    private func provideReuseLocksViewModel() {
        guard let model = deriveReuseLocks() else {
            return
        }

        let governance: String?

        if model.governance > 0 {
            governance = balanceViewModelFactory.amountFromValue(model.governance).value(for: selectedLocale)
        } else {
            governance = nil
        }

        let all: String?

        if model.all > 0, model.all != model.governance {
            all = balanceViewModelFactory.amountFromValue(model.all).value(for: selectedLocale)
        } else {
            all = nil
        }

        let viewModel = ReferendumLockReuseViewModel(governance: governance, all: all)
        view?.didReceiveLockReuse(viewModel: viewModel)
    }

    private func deriveReuseLocks() -> ReferendumReuseLockModel? {
        let governanceLocksInPlank = lockDiff?.before.maxLockedAmount ?? 0
        let allLocksInPlank = assetBalance?.frozenInPlank ?? 0

        guard
            let precision = chain.utilityAssetDisplayInfo()?.assetPrecision,
            let governanceLockDecimal = Decimal.fromSubstrateAmount(governanceLocksInPlank, precision: precision),
            let allLockDecimal = Decimal.fromSubstrateAmount(allLocksInPlank, precision: precision) else {
            return nil
        }

        return ReferendumReuseLockModel(governance: governanceLockDecimal, all: allLockDecimal)
    }
}

extension SwipeGovSetupPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            updateView()
        }
    }
}
