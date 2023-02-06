import Foundation
import SoraFoundation
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
    let quantityFormatter: LocalizableResource<NumberFormatter>
    let logger: LoggerProtocol

    private var votingResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    private var assetBalance: AssetBalance?
    private var price: PriceData?
    private var fee: BigUInt?

    private lazy var walletDisplayViewModelFactory = WalletAccountViewModelFactory()
    private lazy var addressDisplayViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: GovernanceRemoveVotesConfirmInteractorInputProtocol,
        wireframe: GovernanceRemoveVotesConfirmWireframeProtocol,
        tracks: [GovernanceTrackInfoLocal],
        selectedAccount: MetaChainAccountResponse,
        chain: ChainModel,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
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
                fee,
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
        guard let firstTrack = tracks.first else {
            return
        }

        let viewModel: GovernanceTracksViewModel

        if tracks.count > 1 {
            let otherTracks = quantityFormatter.value(for: selectedLocale).string(
                from: NSNumber(value: tracks.count - 1)
            )

            let name = ReferendumTrackType(rawValue: firstTrack.name)?.title(
                for: selectedLocale
            ) ?? firstTrack.name

            let details = R.string.localizable.govRemoveVotesTracksFormat(
                name.firstLetterCapitalized(),
                otherTracks ?? "",
                preferredLanguages: selectedLocale.rLanguages
            )

            viewModel = .init(details: details, canExpand: true)
        } else {
            viewModel = .init(details: firstTrack.name, canExpand: false)
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

    func showTracks() {}

    func confirm() {
        let requests = createRemoveVoteRequests()

        guard
            !requests.isEmpty,
            let assetDisplayInfo = chain.utilityAssetDisplayInfo() else {
            return
        }

        DataValidationRunner(validators: [
            dataValidatingFactory.hasInPlank(
                fee: fee,
                locale: selectedLocale,
                precision: assetDisplayInfo.assetPrecision
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
            self?.interactor.estimateFee(for: requests)
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

    func didReceiveRemoveVotesHash(_: String) {
        view?.didStopLoading()

        wireframe.presentExtrinsicSubmission(from: view, completionAction: .popBack, locale: selectedLocale)
    }

    func didReceiveFee(_ fee: BigUInt) {
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

            if internalError.isWatchOnlySigning {
                wireframe.presentDismissingNoSigningView(from: view)
            } else {
                _ = wireframe.present(error: internalError, from: view, locale: selectedLocale)
            }
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
