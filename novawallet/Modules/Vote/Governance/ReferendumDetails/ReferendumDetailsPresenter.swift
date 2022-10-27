import Foundation
import SoraFoundation
import SubstrateSdk

final class ReferendumDetailsPresenter {
    static let readMoreThreshold = 180

    weak var view: ReferendumDetailsViewProtocol?
    let wireframe: ReferendumDetailsWireframeProtocol
    let interactor: ReferendumDetailsInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let referendumFormatter: LocalizableResource<NumberFormatter>
    let referendumViewModelFactory: ReferendumsModelFactoryProtocol
    let referendumStringsFactory: ReferendumDisplayStringFactoryProtocol
    let referendumTimelineViewModelFactory: ReferendumTimelineViewModelFactoryProtocol
    let referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactoryProtocol
    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol

    let chain: ChainModel
    let logger: LoggerProtocol

    private var referendum: ReferendumLocal
    private var actionDetails: ReferendumActionLocal?
    private var accountVotes: ReferendumAccountVoteLocal?
    private var referendumMetadata: ReferendumMetadataLocal?
    private var identities: [AccountAddress: AccountIdentity]?
    private var price: PriceData?
    private var blockNumber: BlockNumber?
    private var blockTime: BlockTime?
    private var dApps: [GovernanceDApp]?

    private lazy var iconGenerator = PolkadotIconGenerator()

    private var maxStatusTimeInterval: TimeInterval?
    private var countdownTimer: CountdownTimer?
    private var statusViewModel: StatusTimeViewModel?

    init(
        referendum: ReferendumLocal,
        chain: ChainModel,
        interactor: ReferendumDetailsInteractorInputProtocol,
        wireframe: ReferendumDetailsWireframeProtocol,
        referendumViewModelFactory: ReferendumsModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        referendumFormatter: LocalizableResource<NumberFormatter>,
        referendumStringsFactory: ReferendumDisplayStringFactoryProtocol,
        referendumTimelineViewModelFactory: ReferendumTimelineViewModelFactoryProtocol,
        referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactoryProtocol,
        statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol,
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.referendumViewModelFactory = referendumViewModelFactory
        self.referendumStringsFactory = referendumStringsFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.referendumFormatter = referendumFormatter
        self.referendumTimelineViewModelFactory = referendumTimelineViewModelFactory
        self.referendumMetadataViewModelFactory = referendumMetadataViewModelFactory
        self.statusViewModelFactory = statusViewModelFactory
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.referendum = referendum
        self.chain = chain
        self.logger = logger
        self.localizationManager = localizationManager
    }

    deinit {
        invalidateTimer()
    }

    private func provideReferendumInfoViewModel() {
        let referendumIndex = referendumFormatter.value(for: selectedLocale).string(
            from: referendum.index as NSNumber
        )

        let trackViewModel = referendum.track.map {
            ReferendumTrackType.createViewModel(from: $0.name, chain: chain, locale: selectedLocale)
        }

        let viewModel = TrackTagsView.Model(titleIcon: trackViewModel, referendumNumber: referendumIndex)
        view?.didReceive(trackTagsModel: viewModel)
    }

    private func provideTitleViewModel() {
        let accountViewModel: DisplayAddressViewModel?

        if
            let proposer = referendum.proposer,
            let identities = identities,
            let address = try? proposer.toAddress(using: chain.chainFormat) {
            let displayAddress = DisplayAddress(address: address, username: identities[address]?.displayName ?? "")
            accountViewModel = displayAddressViewModelFactory.createViewModel(from: displayAddress)
        } else {
            accountViewModel = nil
        }

        let detailsViewModel = referendumMetadataViewModelFactory.createDetailsViewModel(
            for: referendum,
            metadata: referendumMetadata,
            readMoreThreshold: Self.readMoreThreshold,
            locale: selectedLocale
        )

        let viewModel = ReferendumDetailsTitleView.Model(account: accountViewModel, details: detailsViewModel)

        view?.didReceive(titleModel: viewModel)
    }

    private func provideRequestedAmount() {
        guard
            let requestedAmount = actionDetails?.amountSpendDetails?.amount,
            let precision = chain.utilityAssetDisplayInfo()?.assetPrecision,
            let decimalAmount = Decimal.fromSubstrateAmount(requestedAmount, precision: precision) else {
            view?.didReceive(requestedAmount: nil)
            return
        }

        let balanceViewModel = balanceViewModelFactory.balanceFromPrice(decimalAmount, priceData: price).value(
            for: selectedLocale
        )

        let viewModel: RequestedAmountRow.Model = .init(
            title: R.string.localizable.commonRequestedAmount(preferredLanguages: selectedLocale.rLanguages),
            amount: .init(
                topValue: balanceViewModel.amount,
                bottomValue: balanceViewModel.price
            )
        )

        view?.didReceive(requestedAmount: viewModel)
    }

    private func provideYourVote() {
        if let accountVotes = accountVotes {
            let viewModel = referendumStringsFactory.createYourVotesViewModel(
                from: accountVotes,
                chain: chain,
                locale: selectedLocale
            )

            view?.didReceive(yourVoteModel: viewModel)
        } else {
            view?.didReceive(yourVoteModel: nil)
        }
    }

    private func provideVotingDetails() {
        guard
            let blockNumber = blockNumber,
            let blockTime = blockTime else {
            return
        }

        let chainInfo = ReferendumsModelFactoryInput.ChainInformation(
            chain: chain,
            currentBlock: blockNumber,
            blockDuration: blockTime
        )

        let referendumViewModel = referendumViewModelFactory.createViewModel(
            from: referendum,
            metadata: referendumMetadata,
            vote: accountVotes,
            chainInfo: chainInfo,
            selectedLocale: selectedLocale
        )

        let votingProgress = referendumViewModel.progress
        let status: ReferendumVotingStatusView.Model = .init(
            status: .init(
                name: referendumViewModel.referendumInfo.status.name,
                kind: .init(infoKind: referendumViewModel.referendumInfo.status.kind)
            ),
            time: referendumViewModel.referendumInfo.time.map { .init(titleIcon: $0.titleIcon, isUrgent: $0.isUrgent) },
            title: R.string.localizable.govDetailsVotingStatus(preferredLanguages: selectedLocale.rLanguages)
        )

        let button: String?

        if referendum.canVote {
            if accountVotes != nil {
                button = R.string.localizable.govRevote(preferredLanguages: selectedLocale.rLanguages)
            } else {
                button = R.string.localizable.govVote(preferredLanguages: selectedLocale.rLanguages)
            }
        } else {
            button = nil
        }

        let votes = referendumStringsFactory.createReferendumVotes(
            from: referendum,
            chain: chain,
            locale: selectedLocale
        )

        let viewModel = ReferendumVotingStatusDetailsView.Model(
            status: status,
            votingProgress: votingProgress,
            aye: votes?.ayes,
            nay: votes?.nays,
            buttonText: button
        )

        view?.didReceive(votingDetails: viewModel)
    }

    private func provideDAppViewModel() {
        guard let dApps = dApps else {
            view?.didReceive(dAppModels: nil)
            return
        }

        let viewModels = dApps.map {
            ReferendumDAppView.Model(
                icon: RemoteImageViewModel(url: $0.icon),
                title: $0.name,
                subtitle: $0.subtitle
            )
        }

        view?.didReceive(dAppModels: viewModels)
    }

    private func provideTimelineViewModel() {
        guard
            let blockNumber = blockNumber,
            let blockTime = blockTime else {
            view?.didReceive(timelineModel: nil)
            return
        }

        let timeline = referendumTimelineViewModelFactory.createTimelineViewModel(
            for: referendum,
            metadata: referendumMetadata,
            currentBlock: blockNumber,
            blockDuration: blockTime,
            locale: selectedLocale
        )

        view?.didReceive(timelineModel: timeline)
    }

    private func provideFullDetailsViewModel() {
        let shouldHide = actionDetails == nil
        view?.didReceive(shouldHideFullDetails: shouldHide)
    }

    private func updateView() {
        provideReferendumInfoViewModel()
        provideTitleViewModel()
        provideRequestedAmount()
        provideYourVote()
        provideVotingDetails()
        provideDAppViewModel()
        provideTimelineViewModel()
        provideFullDetailsViewModel()
    }

    private func invalidateTimer() {
        countdownTimer?.delegate = nil
        countdownTimer?.stop()
        countdownTimer = nil
    }

    private func updateTimerIfNeeded() {
        guard
            let blockTime = blockTime,
            let blockNumber = blockNumber else {
            return
        }

        let activeTimeModel = statusViewModelFactory.createTimeViewModel(
            for: referendum,
            currentBlock: blockNumber,
            blockDuration: blockTime,
            locale: selectedLocale
        )

        guard let timeInterval = activeTimeModel?.timeInterval else {
            invalidateTimer()
            view?.didReceive(activeTimeViewModel: activeTimeModel?.viewModel)
            return
        }

        guard maxStatusTimeInterval != timeInterval else {
            return
        }

        maxStatusTimeInterval = timeInterval
        statusViewModel = activeTimeModel

        countdownTimer = CountdownTimer()
        countdownTimer?.delegate = self
        countdownTimer?.start(with: timeInterval)
    }

    private func updateTimerDisplay() {
        guard
            let remainedTimeInterval = countdownTimer?.remainedInterval,
            let statusViewModel = statusViewModel,
            let updatedViewModel = statusViewModel.updateModelClosure(remainedTimeInterval) else {
            return
        }

        view?.didReceive(activeTimeViewModel: updatedViewModel)
    }
}

extension ReferendumDetailsPresenter: ReferendumDetailsPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()
    }

    func vote() {
        wireframe.showVote(from: view, referendum: referendum)
    }

    func showProposerDetails() {
        guard
            let proposerAddress = try? referendum.proposer?.toAddress(using: chain.chainFormat),
            let view = view else {
            return
        }

        wireframe.presentAccountOptions(from: view, address: proposerAddress, chain: chain, locale: selectedLocale)
    }

    func showAyeVoters() {
        wireframe.showVoters(from: view, referendum: referendum, type: .ayes)
    }

    func showNayVoters() {
        wireframe.showVoters(from: view, referendum: referendum, type: .nays)
    }

    func opeDApp(at _: Int) {}

    func readFullDescription() {}

    func openFullDetails() {
        guard let actionDetails = actionDetails else {
            return
        }

        wireframe.showFullDetails(
            from: view,
            referendum: referendum,
            actionDetails: actionDetails,
            identities: identities ?? [:]
        )
    }
}

extension ReferendumDetailsPresenter: ReferendumDetailsInteractorOutputProtocol {
    func didReceiveReferendum(_ referendum: ReferendumLocal) {
        self.referendum = referendum

        provideReferendumInfoViewModel()
        provideVotingDetails()
        provideTitleViewModel()
    }

    func didReceiveActionDetails(_ actionDetails: ReferendumActionLocal) {
        self.actionDetails = actionDetails

        provideTitleViewModel()
        provideRequestedAmount()
        provideFullDetailsViewModel()
    }

    func didReceiveAccountVotes(_ votes: ReferendumAccountVoteLocal?) {
        accountVotes = votes

        provideYourVote()
    }

    func didReceiveMetadata(_ referendumMetadata: ReferendumMetadataLocal?) {
        self.referendumMetadata = referendumMetadata

        provideTitleViewModel()
        provideFullDetailsViewModel()
    }

    func didReceiveIdentities(_ identities: [AccountAddress: AccountIdentity]) {
        self.identities = identities

        provideTitleViewModel()
    }

    func didReceivePrice(_ price: PriceData?) {
        self.price = price

        provideRequestedAmount()
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        self.blockNumber = blockNumber

        interactor.refreshBlockTime()

        provideVotingDetails()
        provideTimelineViewModel()
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime

        provideVotingDetails()
        provideTimelineViewModel()
        updateTimerIfNeeded()
    }

    func didReceiveDApps(_ dApps: [GovernanceDApp]) {
        self.dApps = dApps

        provideDAppViewModel()
    }

    func didReceiveError(_ error: ReferendumDetailsInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .referendumFailed, .accountVotesFailed, .priceFailed, .blockNumberFailed, .metadataFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .actionDetailsFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshActionDetails()
            }
        case .identitiesFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshIdentities()
            }
        case .blockTimeFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshBlockTime()
            }
        case .dAppsFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshDApps()
            }
        }
    }
}

extension ReferendumDetailsPresenter: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {
        updateTimerDisplay()
    }

    func didCountdown(remainedInterval _: TimeInterval) {
        updateTimerDisplay()
    }

    func didStop(with _: TimeInterval) {
        updateTimerDisplay()
    }
}

extension ReferendumDetailsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
