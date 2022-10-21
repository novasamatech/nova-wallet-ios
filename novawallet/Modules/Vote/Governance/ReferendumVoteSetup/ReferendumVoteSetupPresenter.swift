import Foundation
import BigInt
import SoraFoundation

final class ReferendumVoteSetupPresenter {
    weak var view: ReferendumVoteSetupViewProtocol?
    let wireframe: ReferendumVoteSetupWireframeProtocol
    let interactor: ReferendumVoteSetupInteractorInputProtocol

    let chain: ChainModel
    let referendumIndex: ReferendumIdLocal

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let referendumFormatter: LocalizableResource<NumberFormatter>
    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol
    let referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol
    let lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol
    let logger: LoggerProtocol

    private var assetBalance: AssetBalance?
    private var fee: BigUInt?
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
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        referendumFormatter: LocalizableResource<NumberFormatter>,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol,
        interactor: ReferendumVoteSetupInteractorInputProtocol,
        wireframe: ReferendumVoteSetupWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.chain = chain
        self.referendumIndex = referendumIndex
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
        if let assetBalance = assetBalance {
            let precision = chain.utilityAsset()?.displayInfo.assetPrecision ?? 0
            let balanceDecimal = Decimal.fromSubstrateAmount(
                assetBalance.freeInPlank,
                precision: precision
            ) ?? 0

            let viewModel = balanceViewModelFactory.balanceFromPrice(
                balanceDecimal,
                priceData: nil
            ).value(for: selectedLocale).amount

            view?.didReceiveBalance(viewModel: viewModel)
        }
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
            let viewModel = lockChangeViewModelFactory.createAmountViewModel(
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
            let viewModel = lockChangeViewModelFactory.createPeriodViewModel(
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

        let voteValue = vote.voteAction.conviction.votes(for: vote.voteAction.amount) ?? 0

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

    private func updateView() {
        provideReferendumIndex()
        updateAvailableBalanceView()
        provideAmountInputViewModel()
        updateChainAssetViewModel()
        updateAmountPriceView()
        updateVotesView()
        updateLockedAmountView()
        updateLockedPeriodView()
    }

    private func deriveNewVote(isAye: Bool = true) -> ReferendumNewVote? {
        let amount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

        guard
            let precision = chain.utilityAsset()?.displayInfo.assetPrecision,
            let amountInPlank = amount.toSubstrateAmount(precision: precision) else {
            return nil
        }

        let voteAction = ReferendumVoteAction(
            amount: amountInPlank,
            conviction: conviction,
            isAye: isAye
        )

        return ReferendumNewVote(index: referendumIndex, voteAction: voteAction)
    }

    private func refreshFee() {
        guard let newVote = deriveNewVote() else {
            return
        }

        interactor.estimateFee(for: newVote.voteAction)
    }

    private func refreshLockDiff() {
        guard let votesResult = votesResult, let newVote = deriveNewVote() else {
            return
        }

        interactor.refreshLockDiff(
            for: votesResult.value?.votes.votes ?? [:],
            newVote: newVote,
            blockHash: votesResult.blockHash
        )
    }
}

extension ReferendumVoteSetupPresenter: ReferendumVoteSetupPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { .absolute($0) }

        refreshFee()
        refreshLockDiff()

        updateVotesView()
        updateAmountPriceView()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAmountInputViewModel()

        refreshFee()
        refreshLockDiff()

        updateVotesView()
        updateAmountPriceView()
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

    func proceedNay() {
        guard let newVote = deriveNewVote(isAye: false) else {
            return
        }

        wireframe.showConfirmation(from: view, vote: newVote)
    }

    func proceedAye() {
        guard let newVote = deriveNewVote(isAye: true) else {
            return
        }

        wireframe.showConfirmation(from: view, vote: newVote)
    }
}

extension ReferendumVoteSetupPresenter: ReferendumVoteSetupInteractorOutputProtocol {
    func didReceiveLockStateDiff(_ diff: GovernanceLockStateDiff) {
        lockDiff = diff

        updateLockedAmountView()
        updateLockedPeriodView()
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

        refreshFee()
    }

    func didReceivePrice(_ price: PriceData?) {
        priceData = price

        updateAmountPriceView()
    }

    func didReceiveVotingReferendum(_ referendum: ReferendumLocal) {
        self.referendum = referendum
    }

    func didReceiveFee(_ fee: BigUInt) {
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

extension ReferendumVoteSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
