import Foundation
import SoraFoundation
import BigInt

final class GovernanceDelegateConfirmPresenter {
    weak var view: GovernanceDelegateConfirmViewProtocol?
    let wireframe: GovernanceDelegateConfirmWireframeProtocol
    let interactor: GovernanceDelegateConfirmInteractorInputProtocol

    let chain: ChainModel
    let selectedAccount: MetaChainAccountResponse
    let delegation: GovernanceNewDelegation
    let delegationInfo: GovernanceDelegateFlowDisplayInfo

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol
    let lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol
    let dataValidatingFactory: GovernanceValidatorFactoryProtocol
    let trackViewModelFactory: GovernanceTrackViewModelFactoryProtocol
    let logger: LoggerProtocol

    private var assetBalance: AssetBalance?
    private var fee: BigUInt?
    private var priceData: PriceData?
    private var votesResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    private var blockTime: BlockTime?
    private var referendum: ReferendumLocal?
    private var lockDiff: GovernanceDelegateStateDiff?
    private var assetLocks: AssetLocks?

    private lazy var walletDisplayViewModelFactory = WalletAccountViewModelFactory()
    private lazy var addressDisplayViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: GovernanceDelegateConfirmInteractorInputProtocol,
        wireframe: GovernanceDelegateConfirmWireframeProtocol,
        chain: ChainModel,
        selectedAccount: MetaChainAccountResponse,
        delegation: GovernanceNewDelegation,
        delegationInfo: GovernanceDelegateFlowDisplayInfo,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol,
        trackViewModelFactory: GovernanceTrackViewModelFactoryProtocol,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.selectedAccount = selectedAccount
        self.delegation = delegation
        self.delegationInfo = delegationInfo
        self.balanceViewModelFactory = balanceViewModelFactory
        self.referendumStringsViewModelFactory = referendumStringsViewModelFactory
        self.lockChangeViewModelFactory = lockChangeViewModelFactory
        self.trackViewModelFactory = trackViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func provideAmountViewModel() {
        guard
            let precision = chain.utilityAsset()?.displayInfo.assetPrecision,
            let decimalAmount = Decimal.fromSubstrateAmount(
                delegation.balance,
                precision: precision
            ) else {
            return
        }

        let viewModel = balanceViewModelFactory.balanceFromPrice(
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

    private func provideDelegateViewModel() {
        guard let address = try? delegation.delegateId.toAddress(using: chain.chainFormat) else {
            return
        }

        let name = delegationInfo.delegateIdentity?.displayName ?? delegationInfo.delegateMetadata?.name

        let addressViewModel = addressDisplayViewModelFactory.createViewModel(
            from: address,
            name: name,
            iconUrl: delegationInfo.delegateMetadata?.image
        )

        let type: GovernanceDelegateTypeView.Model?

        if let metadata = delegationInfo.delegateMetadata {
            type = metadata.isOrganization ? .organization : .individual
        } else {
            type = nil
        }

        let viewModel = GovernanceDelegateStackCell.Model(
            addressViewModel: addressViewModel,
            type: type
        )

        view?.didReceiveDelegate(viewModel: viewModel)
    }

    private func provideTracksViewModel() {
        guard
            let viewModel = trackViewModelFactory.createTracksRowViewModel(
                from: delegationInfo.selectedTracks,
                chain: chain,
                locale: selectedLocale
            ) else {
            return
        }

        view?.didReceiveTracks(viewModel: viewModel)
    }

    private func provideYourDelegation() {
        let votesString = referendumStringsViewModelFactory.createVotes(
            from: delegation.conviction.votes(for: delegation.balance) ?? 0,
            chain: chain,
            locale: selectedLocale
        )

        let convictionString = referendumStringsViewModelFactory.createVotesDetails(
            from: delegation.balance,
            conviction: delegation.conviction.decimalValue,
            chain: chain,
            locale: selectedLocale
        )

        view?.didReceiveYourDelegation(
            viewModel: .init(votes: votesString ?? "", conviction: convictionString ?? "")
        )
    }

    private func provideTransferableAmountViewModel() {
        guard
            let assetBalance = assetBalance,
            let assetLocks = assetLocks,
            let lockDiff = lockDiff,
            let viewModel = lockChangeViewModelFactory.createTransferableAmountViewModel(
                govLockedAmount: lockDiff.after?.maxLockedAmount,
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
            let viewModel = lockChangeViewModelFactory.createAmountTransitionAfterDelegatingViewModel(
                from: lockDiff,
                locale: selectedLocale
            ) else {
            return
        }

        view?.didReceiveLockedAmount(viewModel: viewModel)
    }

    private func provideUndelegatingPeriodViewModel() {
        guard
            let lockDiff = lockDiff,
            let blockTime = blockTime else {
            return
        }

        let viewModel = lockChangeViewModelFactory.createSinglePeriodViewModel(
            lockDiff.after?.undelegatingPeriod,
            blockTime: blockTime,
            locale: selectedLocale
        )

        view?.didReceiveUndelegatingPeriod(viewModel: viewModel)
    }

    private func refreshFee() {
        guard let voting = votesResult?.value else {
            return
        }

        let actions = delegation.createActions(from: voting)

        interactor.estimateFee(for: actions)
    }

    private func refreshLockDiff() {
        guard let trackVoting = votesResult?.value else {
            return
        }

        interactor.refreshDelegateStateDiff(for: trackVoting, newDelegation: delegation)
    }

    private func updateView() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideTransferableAmountViewModel()
        provideLockedAmountViewModel()
        provideUndelegatingPeriodViewModel()
    }
}

extension GovernanceDelegateConfirmPresenter: GovernanceDelegateConfirmPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func presentSenderAccount() {
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

    func presentDelegateAccount() {
        guard
            let address = try? delegation.delegateId.toAddress(using: chain.chainFormat),
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

    func presentTracks() {
        // TODO:
    }

    func confirm() {
        guard let assetInfo = chain.utilityAssetDisplayInfo() else {
            return
        }

        let params = GovernanceDelegateValidatingParams(
            assetBalance: assetBalance,
            newDelegation: delegation,
            fee: fee,
            votes: votesResult?.value?.votes,
            assetInfo: assetInfo,
            selfAccountId: selectedAccount.chainAccount.accountId
        )

        DataValidationRunner.validateDelegate(
            factory: dataValidatingFactory,
            params: params,
            selectedLocale: selectedLocale,
            feeErrorClosure: { [weak self] in
                self?.refreshFee()
            }, successClosure: { [weak self] in
                guard let delegation = self?.delegation, let voting = self?.votesResult?.value else {
                    return
                }

                self?.view?.didStartLoading()

                let actions = delegation.createActions(from: voting)

                self?.interactor.submit(actions: actions)
            }
        )
    }
}

extension GovernanceDelegateConfirmPresenter: GovernanceDelegateConfirmInteractorOutputProtocol {
    func didReceiveLocks(_ locks: AssetLocks) {
        assetLocks = locks

        provideTransferableAmountViewModel()
    }

    func didReceiveSubmissionHash(_: String) {
        view?.didStopLoading()

        wireframe.presentExtrinsicSubmission(from: view, completionAction: .pop, locale: selectedLocale)
    }

    func didReceiveError(_ error: GovernanceDelegateConfirmInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .locksSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case let .submitFailed(internalError):
            view?.didStopLoading()

            if internalError.isWatchOnlySigning {
                wireframe.presentDismissingNoSigningView(from: view)
            } else {
                _ = wireframe.present(error: internalError, from: view, locale: selectedLocale)
            }
        }
    }

    func didReceiveAssetBalance(_ assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance
    }

    func didReceivePrice(_ priceData: PriceData?) {
        self.priceData = priceData

        provideAmountViewModel()
        provideFeeViewModel()
    }

    func didReceiveFee(_ fee: BigUInt) {
        self.fee = fee

        provideFeeViewModel()
    }

    func didReceiveDelegateStateDiff(_ diff: GovernanceDelegateStateDiff) {
        lockDiff = diff

        provideTransferableAmountViewModel()
        provideLockedAmountViewModel()
        provideUndelegatingPeriodViewModel()
    }

    func didReceiveAccountVotes(_ votes: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {
        votesResult = votes

        refreshLockDiff()
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime

        provideUndelegatingPeriodViewModel()
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

extension GovernanceDelegateConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
