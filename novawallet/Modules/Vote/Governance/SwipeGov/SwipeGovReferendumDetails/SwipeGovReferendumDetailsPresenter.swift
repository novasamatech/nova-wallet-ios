import Foundation
import Foundation_iOS

final class SwipeGovReferendumDetailsPresenter {
    weak var view: SwipeGovReferendumDetailsViewProtocol?
    let wireframe: SwipeGovReferendumDetailsWireframeProtocol
    let interactor: SwipeGovReferendumDetailsInteractorInputProtocol

    let chain: ChainModel
    let governanceType: GovernanceType
    let logger: LoggerProtocol
    let referendumFormatter: LocalizableResource<NumberFormatter>
    let referendumViewModelFactory: ReferendumsModelFactoryProtocol
    let referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactoryProtocol
    let statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol
    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let universalLinkFactory: UniversalLinkFactoryProtocol

    private var referendum: ReferendumLocal
    private var referendumMetadata: ReferendumMetadataLocal?
    private var blockNumber: BlockNumber?
    private var blockTime: BlockTime?
    private var identities: [AccountAddress: AccountIdentity]?
    private var actionDetails: ReferendumActionLocal?

    private var maxStatusTimeInterval: TimeInterval?
    private var countdownTimer: CountdownTimer?
    private var statusViewModel: StatusTimeViewModel?

    init(
        chain: ChainModel,
        governanceType: GovernanceType,
        interactor: SwipeGovReferendumDetailsInteractorInputProtocol,
        wireframe: SwipeGovReferendumDetailsWireframeProtocol,
        referendumFormatter: LocalizableResource<NumberFormatter>,
        referendumViewModelFactory: ReferendumsModelFactoryProtocol,
        referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactoryProtocol,
        statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol,
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        universalLinkFactory: UniversalLinkFactoryProtocol,
        initData: ReferendumDetailsInitData,
        logger: LoggerProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.chain = chain
        self.governanceType = governanceType
        self.interactor = interactor
        self.wireframe = wireframe
        self.referendumFormatter = referendumFormatter
        self.referendumViewModelFactory = referendumViewModelFactory
        self.referendumMetadataViewModelFactory = referendumMetadataViewModelFactory
        self.statusViewModelFactory = statusViewModelFactory
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.universalLinkFactory = universalLinkFactory
        self.logger = logger

        referendum = initData.referendum
        blockNumber = initData.blockNumber
        blockTime = initData.blockTime
        referendumMetadata = initData.metadata

        self.localizationManager = localizationManager
    }
}

// MARK: SwipeGovReferendumDetailsPresenterProtocol

extension SwipeGovReferendumDetailsPresenter: SwipeGovReferendumDetailsPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()
    }

    func showProposerDetails() {
        let referendumProposer = try? referendum.proposer?.toAddress(using: chain.chainFormat)
        let optAddress = referendumProposer ?? referendumMetadata?.proposer

        guard
            let address = optAddress,
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

    func openURL(_ url: URL) {
        guard let view = view else {
            return
        }

        wireframe.showWeb(url: url, from: view, style: .automatic)
    }

    func share() {
        guard let url = universalLinkFactory.createUrl(
            for: chain,
            referendumId: referendum.index,
            type: governanceType
        ) else {
            return
        }

        wireframe.share(items: [url.absoluteString], from: view, with: nil)
    }
}

// MARK: SwipeGovReferendumDetailsInteractorOutputProtocol

extension SwipeGovReferendumDetailsPresenter: SwipeGovReferendumDetailsInteractorOutputProtocol {
    func didReceiveReferendum(_ referendum: ReferendumLocal) {
        self.referendum = referendum

        provideReferendumInfoViewModel()
        provideTitleViewModel()
        updateTimerIfNeeded()

        refreshIdentities()
    }

    func didReceiveIdentities(_ identities: [AccountAddress: AccountIdentity]) {
        self.identities = identities

        provideTitleViewModel()
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        self.blockNumber = blockNumber

        interactor.refreshBlockTime()
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime

        updateTimerIfNeeded()
    }

    func didReceiveActionDetails(_ actionDetails: ReferendumActionLocal) {
        self.actionDetails = actionDetails

        provideTitleViewModel()

        refreshIdentities()
    }

    func didReceiveMetadata(_ referendumMetadata: ReferendumMetadataLocal?) {
        self.referendumMetadata = referendumMetadata

        provideTitleViewModel()

        refreshIdentities()
    }

    func didReceiveError(_ error: SwipeGovDetailsInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .referendumFailed, .blockNumberFailed, .metadataFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .actionDetailsFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshActionDetails()
            }
        case .identitiesFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshIdentities()
            }
        case .blockTimeFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshBlockTime()
            }
        }
    }
}

// MARK: CountdownTimerDelegate

extension SwipeGovReferendumDetailsPresenter: CountdownTimerDelegate {
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

// MARK: Localizable

extension SwipeGovReferendumDetailsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}

// MARK: Private

private extension SwipeGovReferendumDetailsPresenter {
    func refreshIdentities() {
        var accountIds: Set<AccountId> = []

        if let proposer = referendum.proposer {
            accountIds.insert(proposer)
        }

        if let beneficiary = actionDetails?.beneficiary {
            accountIds.insert(beneficiary)
        }

        if let proposer = referendumMetadata?.proposerAccountId(for: chain.chainFormat) {
            accountIds.insert(proposer)
        }

        interactor.refreshIdentities(for: accountIds)
    }

    func updateView() {
        provideReferendumInfoViewModel()
        provideTitleViewModel()
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

// MARK: Private view models

private extension SwipeGovReferendumDetailsPresenter {
    private func provideReferendumInfoViewModel() {
        let referendumIndex = referendumFormatter.value(for: selectedLocale).string(
            from: referendum.index as NSNumber
        )

        // display track name only if there is more than 1 track in the network
        let trackViewModel: ReferendumInfoView.Track?
        if let track = referendum.track, track.totalTracksCount > 1 {
            trackViewModel = ReferendumTrackType.createViewModel(
                from: track.name,
                chain: chain,
                locale: selectedLocale
            )
        } else {
            trackViewModel = nil
        }

        let viewModel = TrackTagsView.Model(titleIcon: trackViewModel, referendumNumber: referendumIndex)
        view?.didReceive(trackTagsModel: viewModel)
    }

    private func provideTitleViewModel() {
        let accountViewModel: DisplayAddressViewModel?

        let optProposer = referendum.proposer ?? referendumMetadata?.proposerAccountId(for: chain.chainFormat)

        if
            let proposer = optProposer,
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
            locale: selectedLocale
        )

        let viewModel = ReferendumDetailsTitleView.Model(account: accountViewModel, details: detailsViewModel)

        view?.didReceive(titleModel: viewModel)
    }

    private func statusViewModel(for referendumViewModel: ReferendumView.Model) -> ReferendumVotingStatusView.Model {
        .init(
            status: .init(
                name: referendumViewModel.referendumInfo.status.name,
                kind: .init(infoKind: referendumViewModel.referendumInfo.status.kind)
            ),
            time: referendumViewModel.referendumInfo.time.map { .init(titleIcon: $0.titleIcon, isUrgent: $0.isUrgent) },
            title: R.string.localizable.govDetailsVotingStatus(preferredLanguages: selectedLocale.rLanguages)
        )
    }
}
