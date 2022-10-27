import Foundation
import BigInt
import SoraFoundation

final class ReferendumVoteConfirmPresenter {
    weak var view: ReferendumVoteConfirmViewProtocol?
    let wireframe: ReferendumVoteConfirmWireframeProtocol
    let interactor: ReferendumVoteConfirmInteractorInputProtocol

    let chain: ChainModel
    let selectedAccount: MetaChainAccountResponse
    let vote: ReferendumNewVote

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let referendumFormatter: LocalizableResource<NumberFormatter>
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
    private var referendum: ReferendumLocal?
    private var lockDiff: GovernanceLockStateDiff?
    private var assetLocks: AssetLocks?

    private lazy var walletDisplayViewModelFactory = WalletAccountViewModelFactory()
    private lazy var addressDisplayViewModelFactory = DisplayAddressViewModelFactory()

    init(
        vote: ReferendumNewVote,
        chain: ChainModel,
        selectedAccount: MetaChainAccountResponse,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        referendumFormatter: LocalizableResource<NumberFormatter>,
        referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol,
        interactor: ReferendumVoteConfirmInteractorInputProtocol,
        wireframe: ReferendumVoteConfirmWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.vote = vote
        self.chain = chain
        self.selectedAccount = selectedAccount
        self.dataValidatingFactory = dataValidatingFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.referendumFormatter = referendumFormatter
        self.referendumStringsViewModelFactory = referendumStringsViewModelFactory
        self.lockChangeViewModelFactory = lockChangeViewModelFactory
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func provideReferendumIndex() {
        let referendumString = referendumFormatter.value(for: selectedLocale).string(from: vote.index as NSNumber)
        view?.didReceive(referendumNumber: referendumString ?? "")
    }

    private func provideAmountViewModel() {
        guard
            let precision = chain.utilityAsset()?.displayInfo.assetPrecision,
            let decimalAmount = Decimal.fromSubstrateAmount(
                vote.voteAction.amount,
                precision: precision
            ) else {
            return
        }

        let viewModel = balanceViewModelFactory.spendingAmountFromPrice(
            decimalAmount,
            priceData: priceData
        ).value(for: selectedLocale)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    private func provideWalletViewModel() {
        guard let viewModel = try? walletDisplayViewModelFactory.createDisplayViewModel(from: selectedAccount) else {
            return
        }

        view?.didReceiveWallet(viewModel: viewModel.cellViewModel)
    }

    private func provideAccountViewModel() {
        guard let address = selectedAccount.chainAccount.toAddress() else {
            return
        }

        let viewModel = addressDisplayViewModelFactory.createViewModel(from: address)
        view?.didReceiveAccount(viewModel: viewModel)
    }

    private func provideFeeViewModel() {
        if let fee = fee {
            guard let precision = chain.utilityAsset()?.displayInfo.assetPrecision else {
                return
            }

            let feeDecimal = Decimal.fromSubstrateAmount(
                fee,
                precision: precision
            ) ?? 0.0

            let viewModel = balanceViewModelFactory.balanceFromPrice(feeDecimal, priceData: priceData)
                .value(for: selectedLocale)

            view?.didReceiveFee(viewModel: viewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func provideYourVoteViewModel() {
        let votesString = referendumStringsViewModelFactory.createVotes(
            from: vote.voteAction.conviction.votes(for: vote.voteAction.amount) ?? 0,
            chain: chain,
            locale: selectedLocale
        )

        let convictionString = referendumStringsViewModelFactory.createVotesDetails(
            from: vote.voteAction.amount,
            conviction: vote.voteAction.conviction.decimalValue,
            chain: chain,
            locale: selectedLocale
        )

        let voteSideString: String
        let voteSideStyle: YourVoteView.Style

        if vote.voteAction.isAye {
            voteSideString = R.string.localizable.governanceAye(preferredLanguages: selectedLocale.rLanguages)
            voteSideStyle = .ayeInverse
        } else {
            voteSideString = R.string.localizable.governanceNay(preferredLanguages: selectedLocale.rLanguages)
            voteSideStyle = .nayInverse
        }

        let voteDescription = R.string.localizable.govYourVote(preferredLanguages: selectedLocale.rLanguages)

        let viewModel = YourVoteRow.Model(
            vote: .init(title: voteSideString.uppercased(), description: voteDescription, style: voteSideStyle),
            amount: .init(topValue: votesString ?? "", bottomValue: convictionString)
        )

        view?.didReceiveYourVote(viewModel: viewModel)
    }

    private func provideTransferableAmountViewModel() {
        guard
            let assetBalance = assetBalance,
            let assetLocks = assetLocks,
            let lockDiff = lockDiff,
            let viewModel = lockChangeViewModelFactory.createTransferableAmountViewModel(
                from: lockDiff,
                balance: assetBalance,
                locks: assetLocks,
                locale: selectedLocale
            ) else {
            return
        }

        view?.didReceiveTransferableAmount(viewModel: viewModel)
    }

    private func provideLockedAmountViewModel() {
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

    private func provideLockedPeriodViewModel() {
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

    private func refreshFee() {
        interactor.estimateFee(for: vote.voteAction)
    }

    private func refreshLockDiff() {
        interactor.refreshLockDiff(
            for: votesResult?.value?.votes.votes ?? [:],
            newVote: vote,
            blockHash: votesResult?.blockHash
        )
    }

    private func updateView() {
        provideReferendumIndex()
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideYourVoteViewModel()
        provideTransferableAmountViewModel()
        provideLockedAmountViewModel()
        provideLockedPeriodViewModel()
    }
}

extension ReferendumVoteConfirmPresenter: ReferendumVoteConfirmPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()

        refreshFee()
    }

    func confirm() {
        guard let assetInfo = chain.utilityAssetDisplayInfo() else {
            return
        }

        let params = GovernanceVoteValidatingParams(
            assetBalance: assetBalance,
            referendum: referendum,
            newVote: vote,
            fee: fee,
            votes: votesResult?.value?.votes,
            assetInfo: assetInfo
        )

        DataValidationRunner.validateVote(
            factory: dataValidatingFactory,
            params: params,
            selectedLocale: selectedLocale,
            feeErrorClosure: { [weak self] in
                self?.refreshFee()
            }, successClosure: { [weak self] in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.view?.didStartLoading()

                strongSelf.interactor.submit(vote: strongSelf.vote.voteAction)
            }
        )
    }

    func presentSenderDetails() {
        guard
            let address = try? selectedAccount.chainAccount.accountId.toAddress(using: chain.chainFormat),
            let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
    }
}

extension ReferendumVoteConfirmPresenter: ReferendumVoteConfirmInteractorOutputProtocol {
    func didReceiveAssetBalance(_ assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance
    }

    func didReceivePrice(_ priceData: PriceData?) {
        self.priceData = priceData

        provideAmountViewModel()
        provideFeeViewModel()
    }

    func didReceiveVotingReferendum(_ referendum: ReferendumLocal) {
        self.referendum = referendum
    }

    func didReceiveFee(_ fee: BigUInt) {
        self.fee = fee

        provideFeeViewModel()
    }

    func didReceiveLockStateDiff(_ diff: GovernanceLockStateDiff) {
        lockDiff = diff

        provideTransferableAmountViewModel()
        provideLockedAmountViewModel()
        provideLockedPeriodViewModel()
    }

    func didReceiveAccountVotes(_ votes: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {
        votesResult = votes

        refreshLockDiff()
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        self.blockNumber = blockNumber

        interactor.refreshBlockTime()

        provideLockedPeriodViewModel()
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime

        provideLockedPeriodViewModel()
    }

    func didReceiveLocks(_ locks: AssetLocks) {
        assetLocks = locks

        provideTransferableAmountViewModel()
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

    func didReceiveVotingHash(_: String) {
        view?.didStopLoading()

        wireframe.presentExtrinsicSubmission(from: view, completionAction: .dismiss, locale: selectedLocale)
    }

    func didReceiveError(_ error: ReferendumVoteConfirmError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .locksSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case let .submitVoteFailed(internalError):
            view?.didStopLoading()

            if internalError.isWatchOnlySigning {
                wireframe.presentDismissingNoSigningView(from: view)
            } else {
                _ = wireframe.present(error: internalError, from: view, locale: selectedLocale)
            }
        }
    }
}

extension ReferendumVoteConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
