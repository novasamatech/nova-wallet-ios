import Foundation
import Foundation_iOS

final class ReferendumVoteSetupPresenter {
    weak var view: ReferendumVoteSetupViewProtocol?
    let wireframe: ReferendumVoteSetupWireframeProtocol
    let interactor: ReferendumVoteSetupInteractorInputProtocol

    let chain: ChainModel
    let referendumIndex: ReferendumIdLocal
    let supportsAbstainVoting: Bool

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let referendumFormatter: LocalizableResource<NumberFormatter>
    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol
    let referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol
    let lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol
    let dataValidatingFactory: GovernanceValidatorFactoryProtocol
    let govBalanceCalculator: AvailableBalanceMapping
    let logger: LoggerProtocol

    private var assetBalance: AssetBalance?
    private var fee: ExtrinsicFeeProtocol?
    private var priceData: PriceData?
    private var votesResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    private var blockNumber: BlockNumber?
    private var blockTime: BlockTime?
    private var referendum: ReferendumLocal?
    private var lockDiff: GovernanceLockStateDiff?

    private(set) var inputResult: AmountInputResult?
    private(set) var conviction: ConvictionVoting.Conviction = .none

    init(
        chain: ChainModel,
        referendumIndex: ReferendumIdLocal,
        initData: ReferendumVotingInitData,
        supportsAbstainVoting: Bool,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        referendumFormatter: LocalizableResource<NumberFormatter>,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol,
        govBalanceCalculator: AvailableBalanceMapping,
        interactor: ReferendumVoteSetupInteractorInputProtocol,
        wireframe: ReferendumVoteSetupWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.chain = chain
        votesResult = initData.votesResult
        blockNumber = initData.blockNumber
        blockTime = initData.blockTime
        referendum = initData.referendum
        lockDiff = initData.lockDiff
        self.referendumIndex = referendumIndex
        self.supportsAbstainVoting = supportsAbstainVoting
        self.dataValidatingFactory = dataValidatingFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        self.referendumFormatter = referendumFormatter
        self.referendumStringsViewModelFactory = referendumStringsViewModelFactory
        self.lockChangeViewModelFactory = lockChangeViewModelFactory
        self.govBalanceCalculator = govBalanceCalculator
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger

        self.localizationManager = localizationManager
    }
}

// MARK: Private

extension ReferendumVoteSetupPresenter {
    private func balanceMinusFee() -> Decimal {
        let balanceValue = govBalanceCalculator.availableBalanceElseZero(from: assetBalance)
        let feeValue = fee?.amountForCurrentAccount ?? 0

        guard
            let precision = chain.utilityAsset()?.displayInfo.assetPrecision,
            let balance = Decimal.fromSubstrateAmount(balanceValue, precision: precision),
            let fee = Decimal.fromSubstrateAmount(feeValue, precision: precision) else {
            return 0
        }

        return balance - fee
    }

    private func updateAvailableBalanceView() {
        let availableInPlank = govBalanceCalculator.mapAvailableBalance(from: assetBalance) ?? 0

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
            let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

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

    private func provideReferendumIndex() {
        let referendumString = referendumFormatter.value(for: selectedLocale).string(from: referendumIndex as NSNumber)
        view?.didReceive(referendumNumber: referendumString ?? "")
    }

    private func provideAbstainAvailable() {
        view?.didReceive(abstainAvailable: supportsAbstainVoting)
    }

    private func provideAmountInputViewModelIfRate() {
        guard case .rate = inputResult else {
            return
        }

        provideAmountInputViewModel()
    }

    private func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

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

    private func updateVotesView() {
        guard let vote = deriveNewVote() else {
            return
        }

        let voteValue = vote.voteAction.conviction().votes(for: vote.voteAction.amount()) ?? 0

        let voteString = referendumStringsViewModelFactory.createVotes(
            from: voteValue,
            chain: chain,
            locale: selectedLocale
        )

        view?.didReceiveVotes(viewModel: voteString ?? "")
    }

    private func provideConviction() {
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

    private func updateView() {
        provideAbstainAvailable()
        provideReferendumIndex()
        updateAvailableBalanceView()
        provideAmountInputViewModel()
        updateChainAssetViewModel()
        updateAmountPriceView()
        updateVotesView()
        updateLockedAmountView()
        updateLockedPeriodView()
        provideReuseLocksViewModel()
    }

    private func deriveNewVote(_ selectedAction: VoteAction = .aye) -> ReferendumNewVote? {
        let amount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

        guard
            let precision = chain.utilityAsset()?.displayInfo.assetPrecision,
            let amountInPlank = amount.toSubstrateAmount(precision: precision) else {
            return nil
        }

        let model = ReferendumVoteActionModel(
            amount: amountInPlank,
            conviction: conviction
        )

        let voteAction: ReferendumVoteAction = switch selectedAction {
        case .aye: .aye(model)
        case .nay: .nay(model)
        case .abstain: .abstain(amount: model.amount)
        }

        return ReferendumNewVote(index: referendumIndex, voteAction: voteAction)
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

    private func refreshFee() {
        guard let newVote = deriveNewVote() else {
            return
        }

        interactor.estimateFee(for: [newVote])
    }

    private func refreshLockDiff() {
        guard let trackVoting = votesResult?.value, let newVote = deriveNewVote() else {
            return
        }

        interactor.refreshLockDiff(
            for: trackVoting,
            newVotes: [newVote]
        )
    }

    private func performValidation(
        for voteAction: VoteAction,
        notifying completionBlock: @escaping DataValidationRunnerCompletion
    ) {
        guard let assetInfo = chain.utilityAssetDisplayInfo() else {
            return
        }

        let newVote = deriveNewVote(voteAction)

        let params = GovernanceVoteValidatingParams(
            assetBalance: assetBalance,
            referendum: referendum,
            newVote: newVote,
            selectedConviction: conviction,
            fee: fee,
            votes: votesResult?.value?.votes,
            assetInfo: assetInfo
        )

        let handlers = GovernanceVoteValidatingHandlers(
            convictionUpdateClosure: { [weak self] in
                self?.selectConvictionValue(0)
                self?.provideConviction()
            },
            feeErrorClosure: { [weak self] in
                self?.refreshFee()
            }
        )

        DataValidationRunner.validateVote(
            factory: dataValidatingFactory,
            params: params,
            selectedLocale: selectedLocale,
            handlers: handlers,
            successClosure: completionBlock
        )
    }

    private func proceed(with voteAction: VoteAction) {
        performValidation(for: voteAction) { [weak self] in
            guard let newVote = self?.deriveNewVote(voteAction) else {
                return
            }

            let initData = ReferendumVotingInitData(
                votesResult: self?.votesResult,
                blockNumber: self?.blockNumber,
                blockTime: self?.blockTime,
                referendum: self?.referendum,
                lockDiff: self?.lockDiff
            )

            self?.wireframe.showConfirmation(
                from: self?.view,
                vote: newVote,
                initData: initData
            )
        }
    }

    private func updateAfterAmountChanged() {
        refreshFee()
        refreshLockDiff()

        updateVotesView()
        updateAmountPriceView()
    }
}

extension ReferendumVoteSetupPresenter: ReferendumVoteSetupPresenterProtocol {
    func setup() {
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

        updateVotesView()

        refreshFee()
        refreshLockDiff()
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

    func proceedNay() {
        proceed(with: .nay)
    }

    func proceedAye() {
        proceed(with: .aye)
    }

    func proceedAbstain() {
        proceed(with: .abstain)
    }
}

extension ReferendumVoteSetupPresenter: ReferendumVoteSetupInteractorOutputProtocol {
    func didReceiveVotingReferendumsState(_ state: ReferendumsState) {
        referendum = state.referendums[referendumIndex]

        let updateAndRefreshClosure: () -> Void = {
            self.votesResult = state.voting
            self.refreshLockDiff()
        }

        guard
            let newVoting = state.voting?.value,
            let votesResult = votesResult?.value,
            newVoting.hasDiff(from: votesResult)
        else {
            if votesResult?.value == nil {
                updateAndRefreshClosure()
            } else {
                votesResult = state.voting
            }

            return
        }

        updateAndRefreshClosure()
    }

    func didReceiveLockStateDiff(_ diff: GovernanceLockStateDiff) {
        lockDiff = diff

        updateLockedAmountView()
        updateLockedPeriodView()
        provideReuseLocksViewModel()
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

        updateAvailableBalanceView()
        updateAmountPriceView()
        provideAmountInputViewModelIfRate()
        provideReuseLocksViewModel()

        refreshFee()
    }

    func didReceivePrice(_ price: PriceData?) {
        priceData = price

        updateAmountPriceView()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        self.fee = fee

        updateAmountPriceView()
        provideAmountInputViewModelIfRate()
    }

    func didReceiveBaseError(_ error: ReferendumVoteInteractorError) {
        logger.error("Did receive base error: \(error)")

        switch error {
        case .assetBalanceFailed, .priceFailed, .votingReferendumFailed, .accountVotesFailed,
             .blockNumberSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .feeFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case .blockTimeFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshBlockTime()
            }
        case .stateDiffFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshLockDiff()
            }
        }
    }
}

extension ReferendumVoteSetupPresenter {
    enum VoteAction {
        case aye
        case nay
        case abstain
    }
}

extension ReferendumVoteSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
