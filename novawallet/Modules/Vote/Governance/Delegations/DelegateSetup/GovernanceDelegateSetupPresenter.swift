import Foundation
import SoraFoundation
import BigInt

final class GovernanceDelegateSetupPresenter {
    weak var view: GovernanceDelegateSetupViewProtocol?
    let wireframe: GovernanceDelegateSetupWireframeProtocol
    let interactor: GovernanceDelegateSetupInteractorInputProtocol

    let chain: ChainModel
    let delegateId: AccountId
    let tracks: [GovernanceTrackInfoLocal]

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol
    let referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol
    let lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol
    let dataValidatingFactory: GovernanceValidatorFactoryProtocol
    let logger: LoggerProtocol

    private var assetBalance: AssetBalance?
    private var fee: BigUInt?
    private var priceData: PriceData?
    private var votesResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    private var blockNumber: BlockNumber?
    private var blockTime: BlockTime?
    private var lockDiff: GovernanceDelegateStateDiff?

    private(set) var inputResult: AmountInputResult?
    private(set) var conviction: ConvictionVoting.Conviction = .none

    init(
        interactor: GovernanceDelegateSetupInteractorInputProtocol,
        wireframe: GovernanceDelegateSetupWireframeProtocol,
        chain: ChainModel,
        delegateId: AccountId,
        tracks: [GovernanceTrackInfoLocal],
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.delegateId = delegateId
        self.tracks = tracks
        self.dataValidatingFactory = dataValidatingFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        self.referendumStringsViewModelFactory = referendumStringsViewModelFactory
        self.lockChangeViewModelFactory = lockChangeViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func balanceMinusFee() -> Decimal {
        let balanceValue = assetBalance?.freeInPlank ?? 0
        let feeValue = fee ?? 0

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
            let viewModel = lockChangeViewModelFactory.createAmountTransitionAfterDelegatingViewModel(
                from: lockDiff,
                locale: selectedLocale
            ) else {
            return
        }

        view?.didReceiveLockedAmount(viewModel: viewModel)
    }

    private func updateUndelegatingView() {
        guard
            let lockDiff = lockDiff,
            let blockTime = blockTime,
            let viewModel = lockChangeViewModelFactory.createPeriodTransitionAfterDelegatingViewModel(
                from: lockDiff,
                blockTime: blockTime,
                locale: selectedLocale
            ) else {
            return
        }

        view?.didReceiveUndelegatingPeriod(viewModel: viewModel)
    }

    private func updateVotesView() {
        guard let delegation = deriveNewDelegation() else {
            return
        }

        let delegatedVotes = delegation.conviction.votes(for: delegation.balance) ?? 0

        let voteString = referendumStringsViewModelFactory.createVotes(
            from: delegatedVotes,
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
        updateAvailableBalanceView()
        provideAmountInputViewModel()
        updateChainAssetViewModel()
        updateAmountPriceView()
        updateVotesView()
        updateLockedAmountView()
        updateUndelegatingView()
        provideReuseLocksViewModel()
    }

    private func deriveNewDelegation() -> GovernanceNewDelegation? {
        let amount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

        guard
            let precision = chain.utilityAsset()?.displayInfo.assetPrecision,
            let amountInPlank = amount.toSubstrateAmount(precision: precision) else {
            return nil
        }

        let trackIds = Set(tracks.map(\.trackId))

        return .init(
            delegateId: delegateId,
            trackIds: trackIds,
            balance: amountInPlank,
            conviction: conviction
        )
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

    private func deriveDelegatorRequest(
        from newDelegate: GovernanceNewDelegation,
        voting: ReferendumTracksVotingDistribution
    ) -> [GovernanceDelegatorAction] {
        newDelegate.trackIds.map { trackId in
            var actions: [GovernanceDelegatorAction] = []

            if voting.votes.delegatings[trackId] != nil {
                actions.append(
                    .init(
                        delegateId: newDelegate.delegateId,
                        trackId: trackId,
                        type: .undelegate
                    )
                )
            }

            actions.append(
                .init(
                    delegateId: newDelegate.delegateId,
                    trackId: trackId,
                    type: .delegate(.init(balance: newDelegate.balance, conviction: newDelegate.conviction))
                )
            )

            return actions
        }.flatMap { $0 }
    }

    private func refreshFee() {
        guard let newDelegation = deriveNewDelegation(), let voting = votesResult?.value else {
            return
        }

        let actions = deriveDelegatorRequest(from: newDelegation, voting: voting)

        interactor.estimateFee(for: actions)
    }

    private func refreshLockDiff() {
        guard let trackVoting = votesResult?.value, let newDelegation = deriveNewDelegation() else {
            return
        }

        interactor.refreshDelegateStateDiff(
            for: trackVoting,
            newDelegation: newDelegation,
            blockHash: votesResult?.blockHash
        )
    }

    private func updateAfterAmountChanged() {
        refreshFee()
        refreshLockDiff()

        updateVotesView()
        updateAmountPriceView()
    }
}

extension GovernanceDelegateSetupPresenter: GovernanceDelegateSetupPresenterProtocol {
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

    func proceed() {
        // TODO:
    }
}

extension GovernanceDelegateSetupPresenter: GovernanceDelegateSetupInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        assetBalance = balance

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

    func didReceiveFee(_ fee: BigUInt) {
        self.fee = fee

        updateAmountPriceView()
        provideAmountInputViewModelIfRate()
    }

    func didReceiveDelegateStateDiff(_ stateDiff: GovernanceDelegateStateDiff) {
        lockDiff = stateDiff

        updateLockedAmountView()
        updateUndelegatingView()
        provideReuseLocksViewModel()
    }

    func didReceiveAccountVotes(_ votes: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {
        votesResult = votes

        refreshLockDiff()
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        self.blockNumber = blockNumber

        interactor.refreshBlockTime()

        updateLockedAmountView()
        updateUndelegatingView()
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime

        updateLockedAmountView()
        updateUndelegatingView()
    }

    func didReceiveBaseError(_ error: GovernanceDelegateInteractorError) {
        logger.error("Did receive base error: \(error)")

        switch error {
        case .assetBalanceFailed, .priceFailed, .accountVotesFailed,
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

extension GovernanceDelegateSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
