import Foundation
import Foundation_iOS
import BigInt

final class GovernanceRemoveVotesConfirmPresenter {
    weak var view: GovernanceRemoveVotesConfirmViewProtocol?
    let wireframe: GovernanceRemoveVotesConfirmWireframeProtocol
    let interactor: GovernanceRemoveVotesConfirmInteractorInputProtocol

    let chain: ChainModel
    let selectedAccount: MetaChainAccountResponse
    let tracks: [GovernanceTrackInfoLocal]
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: GovernanceValidatorFactoryProtocol
    let trackViewModelFactory: GovernanceTrackViewModelFactoryProtocol
    let quantityFormatter: LocalizableResource<NumberFormatter>
    let logger: LoggerProtocol

    private var votingResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    private var assetBalance: AssetBalance?
    private var price: PriceData?
    private var fee: ExtrinsicFeeProtocol?

    private lazy var walletDisplayViewModelFactory = WalletAccountViewModelFactory()
    private lazy var addressDisplayViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: GovernanceRemoveVotesConfirmInteractorInputProtocol,
        wireframe: GovernanceRemoveVotesConfirmWireframeProtocol,
        tracks: [GovernanceTrackInfoLocal],
        selectedAccount: MetaChainAccountResponse,
        chain: ChainModel,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        trackViewModelFactory: GovernanceTrackViewModelFactoryProtocol,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        quantityFormatter: LocalizableResource<NumberFormatter>,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.tracks = tracks
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.balanceViewModelFactory = balanceViewModelFactory
        self.trackViewModelFactory = trackViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.quantityFormatter = quantityFormatter
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func updateWalletView() {
        guard let viewModel = try? walletDisplayViewModelFactory.createDisplayViewModel(from: selectedAccount) else {
            return
        }

        view?.didReceiveWallet(viewModel: viewModel.cellViewModel)
    }

    private func updateAccountView() {
        guard let address = selectedAccount.chainAccount.toAddress() else {
            return
        }

        let viewModel = addressDisplayViewModelFactory.createViewModel(from: address)
        view?.didReceiveAccount(viewModel: viewModel)
    }

    private func updateFeeView() {
        if let fee = fee {
            guard let precision = chain.utilityAsset()?.displayInfo.assetPrecision else {
                return
            }

            let feeDecimal = Decimal.fromSubstrateAmount(
                fee.amount,
                precision: precision
            ) ?? 0.0

            let viewModel = balanceViewModelFactory.balanceFromPrice(feeDecimal, priceData: price)
                .value(for: selectedLocale)

            view?.didReceiveFee(viewModel: viewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func updateTracksView() {
        guard
            let viewModel = trackViewModelFactory.createTracksRowViewModel(
                from: tracks,
                locale: selectedLocale
            ) else {
            return
        }

        view?.didReceiveTracks(viewModel: viewModel)
    }

    private func updateViews() {
        updateWalletView()
        updateAccountView()
        updateFeeView()
        updateTracksView()
    }

    private func createRemoveVoteRequests() -> [GovernanceRemoveVoteRequest] {
        guard let votingResult = votingResult else {
            return []
        }

        let votedTracks = votingResult.value?.votes.votedTracks ?? [:]

        return tracks.map { track -> [GovernanceRemoveVoteRequest] in
            guard let referendumIds = votedTracks[track.trackId] else {
                return []
            }

            return referendumIds.map { referendumId in
                GovernanceRemoveVoteRequest(trackId: track.trackId, referendumId: referendumId)
            }
        }.flatMap { $0 }
    }

    private func refreshFee() {
        let requests = createRemoveVoteRequests()
        guard !requests.isEmpty else {
            return
        }

        interactor.estimateFee(for: requests)
    }
}

extension GovernanceRemoveVotesConfirmPresenter: GovernanceRemoveVotesConfirmPresenterProtocol {
    func setup() {
        updateViews()

        interactor.setup()
    }

    func showAccountOptions() {
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

    func showTracks() {
        wireframe.showTracks(from: view, tracks: tracks)
    }

    func confirm() {
        let requests = createRemoveVoteRequests()

        guard
            !requests.isEmpty,
            let assetDisplayInfo = chain.utilityAssetDisplayInfo() else {
            return
        }

        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                fee: fee,
                locale: selectedLocale
            ) { [weak self] in
                self?.refreshFee()
            },
            dataValidatingFactory.canPayFeeInPlank(
                balance: assetBalance?.transferable,
                fee: fee,
                asset: assetDisplayInfo,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            self?.view?.didStartLoading()
            self?.interactor.submit(requests: requests)
        }
    }
}

extension GovernanceRemoveVotesConfirmPresenter: GovernanceRemoveVotesConfirmInteractorOutputProtocol {
    func didReceiveVotingResult(_ votingResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {
        self.votingResult = votingResult

        refreshFee()
    }

    func didReceiveBalance(_ assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance
    }

    func didReceivePrice(_ price: PriceData?) {
        self.price = price

        updateFeeView()
    }

    func didReceiveSubmissionResult(_ result: SubmitIndexedExtrinsicResult) {
        view?.didStopLoading()

        let handlers = MultiExtrinsicResultActions(
            onSuccess: { [weak self] in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.wireframe.presentExtrinsicSubmission(
                    from: strongSelf.view,
                    sender: result.senders().first,
                    completionAction: .popBack,
                    locale: strongSelf.selectedLocale
                )
            }, onErrorRetry: { [weak self] closure, indexes in
                self?.view?.didStartLoading()

                self?.interactor.retryMultiExtrinsic(
                    for: closure,
                    indexes: indexes
                )
            }, onErrorSkip: { [weak self] in
                self?.wireframe.skip(on: self?.view)
            }
        )

        wireframe.presentMultiExtrinsicStatusFromResult(
            on: view,
            result: result,
            locale: selectedLocale,
            handlers: handlers
        )
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        self.fee = fee

        updateFeeView()
    }

    func didReceiveError(_ error: GovernanceRemoveVotesInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .votesSubsctiptionFailed, .balanceSubscriptionFailed, .priceSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .feeFetchFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case let .removeVotesFailed(internalError):
            view?.didStopLoading()

            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                internalError,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }
}

extension GovernanceRemoveVotesConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateViews()
        }
    }
}
