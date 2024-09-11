import Foundation
import BigInt
import SoraFoundation

class BaseReferendumVoteSetupPresenter {
    weak var baseView: BaseReferendumVoteSetupViewProtocol?
    private let wireframe: BaseReferendumVoteSetupWireframeProtocol
    private let interactor: ReferendumVoteSetupInteractorInputProtocol

    let chain: ChainModel
    let referendumIndex: ReferendumIdLocal

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let referendumFormatter: LocalizableResource<NumberFormatter>
    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol
    let referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol
    let lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol
    let dataValidatingFactory: GovernanceValidatorFactoryProtocol
    let logger: LoggerProtocol

    private(set) var assetBalance: AssetBalance?
    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var priceData: PriceData?
    private(set) var votesResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    private(set) var blockNumber: BlockNumber?
    private(set) var blockTime: BlockTime?
    private(set) var referendum: ReferendumLocal?
    private(set) var lockDiff: GovernanceLockStateDiff?

    private(set) var inputResult: AmountInputResult?
    private(set) var conviction: ConvictionVoting.Conviction = .none

    init(
        chain: ChainModel,
        referendumIndex: ReferendumIdLocal,
        initData: ReferendumVotingInitData,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        referendumFormatter: LocalizableResource<NumberFormatter>,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol,
        interactor: ReferendumVoteSetupInteractorInputProtocol,
        wireframe: BaseReferendumVoteSetupWireframeProtocol,
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
        self.dataValidatingFactory = dataValidatingFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        self.referendumFormatter = referendumFormatter
        self.referendumStringsViewModelFactory = referendumStringsViewModelFactory
        self.lockChangeViewModelFactory = lockChangeViewModelFactory
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger

        self.localizationManager = localizationManager
    }

    func updateView() {
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
}

// MARK: Private

extension BaseReferendumVoteSetupPresenter {
    func balanceMinusFee() -> Decimal {
        let balanceValue = assetBalance?.freeInPlank ?? 0
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
        let freeInPlank = assetBalance?.freeInPlank ?? 0

        let precision = chain.utilityAsset()?.displayInfo.assetPrecision ?? 0
        let balanceDecimal = Decimal.fromSubstrateAmount(
            freeInPlank,
            precision: precision
        ) ?? 0

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            balanceDecimal,
            priceData: nil
        ).value(for: selectedLocale).amount

        baseView?.didReceiveBalance(viewModel: viewModel)
    }

    private func updateChainAssetViewModel() {
        guard let asset = chain.utilityAsset() else {
            return
        }

        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let viewModel = chainAssetViewModelFactory.createViewModel(from: chainAsset)
        baseView?.didReceiveInputChainAsset(viewModel: viewModel)
    }

    private func updateAmountPriceView() {
        if chain.utilityAsset()?.priceId != nil {
            let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

            let priceData = priceData ?? PriceData.zero()

            let price = balanceViewModelFactory.priceFromAmount(
                inputAmount,
                priceData: priceData
            ).value(for: selectedLocale)

            baseView?.didReceiveAmountInputPrice(viewModel: price)
        } else {
            baseView?.didReceiveAmountInputPrice(viewModel: nil)
        }
    }

    private func provideReferendumIndex() {
        let referendumString = referendumFormatter.value(for: selectedLocale).string(from: referendumIndex as NSNumber)
        baseView?.didReceive(referendumNumber: referendumString ?? "")
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

        baseView?.didReceiveAmount(inputViewModel: viewModel)
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

        baseView?.didReceiveLockedAmount(viewModel: viewModel)
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

        baseView?.didReceiveLockedPeriod(viewModel: viewModel)
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

        baseView?.didReceiveVotes(viewModel: voteString ?? "")
    }

    func provideConviction() {
        baseView?.didReceiveConviction(viewModel: UInt(conviction.rawValue))
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
        baseView?.didReceiveLockReuse(viewModel: viewModel)
    }

    func deriveNewVote(_ selectedAction: VoteAction = .aye) -> ReferendumNewVote? {
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

    func refreshFee() {
        guard let newVote = deriveNewVote() else {
            return
        }

        interactor.estimateFee(for: newVote.voteAction)
    }

    private func refreshLockDiff() {
        guard let trackVoting = votesResult?.value, let newVote = deriveNewVote() else {
            return
        }

        interactor.refreshLockDiff(
            for: trackVoting,
            newVote: newVote,
            blockHash: votesResult?.blockHash
        )
    }

    func processSuccessValidation(with _: ProceedStrategy?) {}

    private func updateAfterAmountChanged() {
        refreshFee()
        refreshLockDiff()

        updateVotesView()
        updateAmountPriceView()
    }
}

extension BaseReferendumVoteSetupPresenter: BaseReferendumVoteSetupPresenterProtocol {
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
}

extension BaseReferendumVoteSetupPresenter: ReferendumVoteSetupInteractorOutputProtocol {
    func didReceiveLockStateDiff(_ diff: GovernanceLockStateDiff) {
        lockDiff = diff

        updateLockedAmountView()
        updateLockedPeriodView()
        provideReuseLocksViewModel()
    }

    func didReceiveAccountVotes(
        _ votes: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>
    ) {
        votesResult = votes

        refreshLockDiff()
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

    func didReceiveVotingReferendum(_ referendum: ReferendumLocal) {
        self.referendum = referendum
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
            wireframe.presentRequestStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .feeFailed:
            wireframe.presentFeeStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case .blockTimeFailed:
            wireframe.presentRequestStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshBlockTime()
            }
        case .stateDiffFailed:
            wireframe.presentRequestStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.refreshLockDiff()
            }
        case let .votingPowerSaveFailed(error):
            wireframe.present(
                error: error,
                from: baseView,
                locale: selectedLocale
            )
        }
    }
}

extension BaseReferendumVoteSetupPresenter {
    enum VoteAction {
        case aye
        case nay
        case abstain
    }

    enum ProceedStrategy {
        case vote(ReferendumNewVote)
        case noVote
    }
}

extension BaseReferendumVoteSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = baseView, view.isSetup {
            updateView()
        }
    }
}
