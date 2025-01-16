import Foundation
import BigInt
import Foundation_iOS

class BaseReferendumVoteConfirmPresenter {
    weak var baseView: BaseReferendumVoteConfirmViewProtocol?
    private let wireframe: BaseReferendumVoteConfirmWireframeProtocol
    private let interactor: ReferendumVoteInteractorInputProtocol

    let chain: ChainModel
    let selectedAccount: MetaChainAccountResponse

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let referendumFormatter: LocalizableResource<NumberFormatter>
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
    private(set) var lockDiff: GovernanceLockStateDiff?
    private(set) var assetLocks: AssetLocks?

    private(set) lazy var walletDisplayViewModelFactory = WalletAccountViewModelFactory()
    private(set) lazy var addressDisplayViewModelFactory = DisplayAddressViewModelFactory()

    init(
        initData: ReferendumVotingInitData,
        chain: ChainModel,
        selectedAccount: MetaChainAccountResponse,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        referendumFormatter: LocalizableResource<NumberFormatter>,
        referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol,
        interactor: ReferendumVoteInteractorInputProtocol,
        wireframe: BaseReferendumVoteConfirmWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.chain = chain
        self.selectedAccount = selectedAccount
        votesResult = initData.votesResult
        blockNumber = initData.blockNumber
        blockTime = initData.blockTime
        lockDiff = initData.lockDiff
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

    private func provideWalletViewModel() {
        guard let viewModel = try? walletDisplayViewModelFactory.createDisplayViewModel(from: selectedAccount) else {
            return
        }

        baseView?.didReceiveWallet(viewModel: viewModel.cellViewModel)
    }

    private func provideAccountViewModel() {
        guard let address = selectedAccount.chainAccount.toAddress() else {
            return
        }

        let viewModel = addressDisplayViewModelFactory.createViewModel(from: address)
        baseView?.didReceiveAccount(viewModel: viewModel)
    }

    private func provideFeeViewModel() {
        if let fee = fee {
            guard let precision = chain.utilityAsset()?.displayInfo.assetPrecision else {
                return
            }

            let feeDecimal = Decimal.fromSubstrateAmount(
                fee.amount,
                precision: precision
            ) ?? 0.0

            let viewModel = balanceViewModelFactory.balanceFromPrice(feeDecimal, priceData: priceData)
                .value(for: selectedLocale)

            baseView?.didReceiveFee(viewModel: viewModel)
        } else {
            baseView?.didReceiveFee(viewModel: nil)
        }
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

        baseView?.didReceiveTransferableAmount(viewModel: viewModel)
    }

    private func provideLockedAmountViewModel() {
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

    private func provideLockedPeriodViewModel() {
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

    func updateView() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideTransferableAmountViewModel()
        provideLockedAmountViewModel()
        provideLockedPeriodViewModel()
    }

    func setup() {
        updateView()
        interactor.setup()
        refreshFee()
    }

    func provideAmountViewModel() {
        fatalError("Must be overriden by subsclass")
    }

    func refreshFee() {
        fatalError("Must be overriden by subsclass")
    }

    func refreshLockDiff() {
        fatalError("Must be overriden by subsclass")
    }

    func confirm() {
        fatalError("Must be overriden by subsclass")
    }

    func didReceiveVotingReferendumsState(_ state: ReferendumsState) {
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
}

extension BaseReferendumVoteConfirmPresenter: ReferendumVoteConfirmPresenterProtocol {
    func presentSenderDetails() {
        guard
            let address = try? selectedAccount.chainAccount.accountId.toAddress(using: chain.chainFormat),
            let view = baseView else {
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

extension BaseReferendumVoteConfirmPresenter: BaseReferendumVoteConfirmInteractorOutputProtocol {
    func didReceiveAssetBalance(_ assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance
    }

    func didReceivePrice(_ priceData: PriceData?) {
        self.priceData = priceData

        provideAmountViewModel()
        provideFeeViewModel()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        self.fee = fee

        provideFeeViewModel()
    }

    func didReceiveLockStateDiff(_ diff: GovernanceLockStateDiff) {
        lockDiff = diff

        provideTransferableAmountViewModel()
        provideLockedAmountViewModel()
        provideLockedPeriodViewModel()
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
        }
    }

    func didReceiveError(_ error: ReferendumVoteConfirmError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .locksSubscriptionFailed:
            wireframe.presentRequestStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case let .submitVoteFailed(internalError):
            baseView?.didStopLoading()

            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                internalError,
                view: baseView,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }
}

extension BaseReferendumVoteConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = baseView, view.isSetup {
            updateView()
        }
    }
}
