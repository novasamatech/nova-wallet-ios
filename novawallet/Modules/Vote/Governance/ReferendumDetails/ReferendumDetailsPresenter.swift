import Foundation
import Foundation_iOS
import SubstrateSdk

final class ReferendumDetailsPresenter {
    weak var view: ReferendumDetailsViewProtocol?
    let wireframe: ReferendumDetailsWireframeProtocol
    let interactor: ReferendumDetailsInteractorInputProtocol
    let balanceViewModelFacade: BalanceViewModelFactoryFacadeProtocol
    let referendumFormatter: LocalizableResource<NumberFormatter>
    let referendumViewModelFactory: ReferendumsModelFactoryProtocol
    let referendumVotesFactory: ReferendumVotesViewModelFactoryProtocol
    let referendumTimelineViewModelFactory: ReferendumTimelineViewModelFactoryProtocol
    let referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactoryProtocol
    let endedReferendumProgressViewModelFactory: EndedReferendumProgressViewModelFactoryProtocol
    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol
    let accountManagementFilter: AccountManagementFilterProtocol
    let universalLinkFactory: UniversalLinkFactoryProtocol
    let wallet: MetaAccountModel

    let chain: ChainModel
    let governanceType: GovernanceType
    let logger: LoggerProtocol

    private var referendum: ReferendumLocal
    private var offchainVotingAmount: ReferendumVotingAmount?
    private var actionDetails: ReferendumActionLocal?
    private var accountVotes: ReferendumAccountVoteLocal?
    private var offchainVoting: GovernanceOffchainVotesLocal.Single?
    private var referendumMetadata: ReferendumMetadataLocal?
    private var identities: [AccountAddress: AccountIdentity]?
    private var requestedAmountPrice: PriceData?
    private var blockNumber: BlockNumber?
    private var blockTime: BlockTime?
    private var dApps: [GovernanceDApps.DApp]?
    private let votingAvailable: Bool

    private lazy var iconGenerator = PolkadotIconGenerator()

    private var maxStatusTimeInterval: TimeInterval?
    private var countdownTimer: CountdownTimer?
    private var statusViewModel: StatusTimeViewModel?

    init(
        chain: ChainModel,
        governanceType: GovernanceType,
        wallet: MetaAccountModel,
        accountManagementFilter: AccountManagementFilterProtocol,
        initData: ReferendumDetailsInitData,
        interactor: ReferendumDetailsInteractorInputProtocol,
        wireframe: ReferendumDetailsWireframeProtocol,
        referendumViewModelFactory: ReferendumsModelFactoryProtocol,
        balanceViewModelFacade: BalanceViewModelFactoryFacadeProtocol,
        referendumFormatter: LocalizableResource<NumberFormatter>,
        referendumVotesFactory: ReferendumVotesViewModelFactoryProtocol,
        referendumTimelineViewModelFactory: ReferendumTimelineViewModelFactoryProtocol,
        referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactoryProtocol,
        endedReferendumProgressViewModelFactory: EndedReferendumProgressViewModelFactoryProtocol,
        statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol,
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        universalLinkFactory: UniversalLinkFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.wallet = wallet
        self.governanceType = governanceType
        self.accountManagementFilter = accountManagementFilter
        self.referendumViewModelFactory = referendumViewModelFactory
        self.referendumVotesFactory = referendumVotesFactory
        self.balanceViewModelFacade = balanceViewModelFacade
        self.referendumFormatter = referendumFormatter
        self.referendumTimelineViewModelFactory = referendumTimelineViewModelFactory
        self.referendumMetadataViewModelFactory = referendumMetadataViewModelFactory
        self.endedReferendumProgressViewModelFactory = endedReferendumProgressViewModelFactory
        self.statusViewModelFactory = statusViewModelFactory
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.universalLinkFactory = universalLinkFactory
        referendum = initData.referendum
        accountVotes = initData.accountVotes
        offchainVoting = initData.offchainVoting
        blockNumber = initData.blockNumber
        blockTime = initData.blockTime
        referendumMetadata = initData.metadata
        votingAvailable = initData.votingAvailable
        self.chain = chain
        self.logger = logger
        self.localizationManager = localizationManager
    }

    deinit {
        invalidateTimer()
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

    private func refreshIdentities() {
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
}

// MARK: Provide View Models

extension ReferendumDetailsPresenter {
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

    private func provideRequestedAmount() {
        guard
            let requestedAmount = actionDetails?.requestedAmount(),
            let chainAssetInfo = requestedAmount.otherChainAssetOrCurrentUtility(from: chain)?.assetDisplayInfo else {
            view?.didReceive(requestedAmount: nil)
            return
        }

        let balanceViewModel = balanceViewModelFacade.balanceFromPrice(
            targetAssetInfo: chainAssetInfo,
            amount: requestedAmount.value.decimal(assetInfo: chainAssetInfo),
            priceData: requestedAmountPrice
        ).value(for: selectedLocale)

        let viewModel: RequestedAmountRow.Model = .init(
            title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonRequestedAmount(),
            amount: .init(
                topValue: balanceViewModel.amount,
                bottomValue: balanceViewModel.price
            )
        )

        view?.didReceive(requestedAmount: viewModel)
    }

    private func provideYourVote() {
        let viewModel: [YourVoteRow.Model]

        if let accountVotes = accountVotes {
            viewModel = referendumVotesFactory.createDirectVotesViewModel(
                from: accountVotes,
                chain: chain,
                locale: selectedLocale
            )
        } else if let offchainVoting = offchainVoting {
            switch offchainVoting.voteType {
            case let .direct(directVote):
                viewModel = referendumVotesFactory.createDirectVotesViewModel(
                    from: directVote,
                    chain: chain,
                    locale: selectedLocale
                )
            case let .delegated(delegateVote):
                viewModel = referendumVotesFactory.createDelegatorVotesViaDelegateViewModel(
                    from: delegateVote,
                    delegateName: offchainVoting.identity?.displayName ?? offchainVoting.metadata?.name,
                    chain: chain,
                    locale: selectedLocale
                )
            }
        } else {
            viewModel = []
        }

        view?.didReceive(yourVoteModel: viewModel)
    }

    private func provideDAppViewModel() {
        guard let dApps = dApps else {
            view?.didReceive(dAppModels: nil)
            return
        }

        let viewModels = dApps.map {
            DAppView.Model(
                icon: RemoteImageViewModel(url: $0.icon),
                title: $0.title,
                subtitle: $0.details
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
        let shouldHide = actionDetails == nil || referendum.state.completed
        view?.didReceive(shouldHideFullDetails: shouldHide)
    }

    private func provideVotingDetails() {
        guard let blockNumber = blockNumber, let blockTime = blockTime else {
            return
        }

        let chainInfo = ReferendumsModelFactoryInput.ChainInformation(
            chain: chain,
            currentBlock: blockNumber,
            blockDuration: blockTime
        )

        let referendumViewModel = referendumViewModelFactory.createViewModel(
            input: .init(
                referendum: referendum,
                metadata: referendumMetadata,
                onchainVotes: accountVotes,
                offchainVotes: nil,
                chainInfo: chainInfo,
                selectedLocale: selectedLocale
            )
        )

        let votes = referendumVotesFactory.createReferendumVotes(
            from: referendum,
            offchainVotingAmount: offchainVotingAmount,
            chain: chain,
            locale: selectedLocale
        )

        let votingProgress: LoadableViewModelState<VotingProgressView.Model?> = {
            if let progress = referendumViewModel.progress {
                .loaded(value: progress)
            } else {
                endedReferendumProgressViewModelFactory.createLoadableViewModel(
                    votingAmount: offchainVotingAmount,
                    locale: selectedLocale
                )
            }
        }()

        let viewModel = ReferendumVotingStatusDetailsView.Model(
            status: statusViewModel(for: referendumViewModel),
            votingProgress: votingProgress,
            aye: votes.ayes,
            nay: votes.nays,
            abstain: votes.abstains,
            buttonText: buttonText()
        )

        view?.didReceive(votingDetails: viewModel)
    }

    private func statusViewModel(for referendumViewModel: ReferendumView.Model) -> ReferendumVotingStatusView.Model {
        .init(
            status: .init(
                name: referendumViewModel.referendumInfo.status.name,
                kind: .init(infoKind: referendumViewModel.referendumInfo.status.kind)
            ),
            time: referendumViewModel.referendumInfo.time.map { .init(titleIcon: $0.titleIcon, isUrgent: $0.isUrgent) },
            title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govDetailsVotingStatus()
        )
    }

    private func buttonText() -> String? {
        let button: String?

        if referendum.canVote, votingAvailable {
            if accountVotes != nil {
                button = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govRevote()
            } else {
                button = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govVote()
            }
        } else {
            button = nil
        }

        return button
    }

    private func createAccountValidationHandlers() -> (
        success: () -> Void,
        newAccount: () -> Void
    ) {
        let successHandler: () -> Void = { [weak self] in
            guard let self else { return }

            let initData = ReferendumVotingInitData(
                votesResult: nil,
                blockNumber: blockNumber,
                blockTime: blockTime,
                referendum: referendum,
                lockDiff: nil
            )

            wireframe.showVote(
                from: view,
                referendum: referendum,
                initData: initData
            )
        }

        let newAccountHandler: () -> Void = { [weak self] in
            guard let self else { return }

            wireframe.showWalletDetails(
                from: view,
                wallet: wallet
            )
        }

        return (successHandler, newAccountHandler)
    }
}

// MARK: ReferendumDetailsPresenterProtocol

extension ReferendumDetailsPresenter: ReferendumDetailsPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()
    }

    func vote() {
        guard let view = view else {
            return
        }

        let addAccountAskMessage = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonChainCrowdloanAccountMissingMessage(chain.name)

        let handlers = createAccountValidationHandlers()

        let params = WalletNoAccountHandlingParams(
            wallet: wallet,
            chain: chain,
            accountManagementFilter: accountManagementFilter,
            successHandler: handlers.success,
            newAccountHandler: handlers.newAccount,
            addAccountAskMessage: addAccountAskMessage
        )

        validateAccount(
            from: params,
            view: view,
            wireframe: wireframe,
            locale: selectedLocale
        )
    }

    func showProposerDetails() {
        let referendumProposer = try? referendum.proposer?.toAddress(using: chain.chainFormat)
        let optAddress = referendumProposer ?? referendumMetadata?.proposer

        guard
            let address = optAddress,
            let view = view else {
            return
        }

        wireframe.presentAccountOptions(from: view, address: address, chain: chain, locale: selectedLocale)
    }

    func showAyeVoters() {
        wireframe.showVoters(from: view, referendum: referendum, type: .ayes)
    }

    func showNayVoters() {
        wireframe.showVoters(from: view, referendum: referendum, type: .nays)
    }

    func showAbstainVoters() {
        wireframe.showVoters(from: view, referendum: referendum, type: .abstains)
    }

    func opeDApp(at index: Int) {
        guard
            let dApp = dApps?[index],
            let url = try? dApp.extractFullUrl(for: referendum.index, governanceType: governanceType)
        else {
            return
        }

        wireframe.openBrowser(with: .query(string: url.absoluteString))
    }

    func readFullDescription() {
        let viewModel = referendumMetadataViewModelFactory.createDetailsViewModel(
            for: referendum,
            metadata: referendumMetadata,
            locale: selectedLocale
        )

        wireframe.showFullDescription(from: view, title: viewModel.title, description: viewModel.description)
    }

    func openFullDetails() {
        guard let actionDetails = actionDetails else {
            return
        }

        wireframe.showFullDetails(
            from: view,
            referendum: referendum,
            actionDetails: actionDetails,
            metadata: referendumMetadata,
            identities: identities ?? [:]
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

// MARK: ReferendumDetailsInteractorOutputProtocol

extension ReferendumDetailsPresenter: ReferendumDetailsInteractorOutputProtocol {
    func didReceiveReferendum(_ referendum: ReferendumLocal) {
        self.referendum = referendum

        provideReferendumInfoViewModel()
        provideVotingDetails()
        provideTitleViewModel()
        updateTimerIfNeeded()

        refreshIdentities()
    }

    func didReceiveVotingAmount(_ amount: ReferendumVotingAmount) {
        offchainVotingAmount = amount

        provideVotingDetails()
    }

    func didReceiveActionDetails(_ actionDetails: ReferendumActionLocal) {
        self.actionDetails = actionDetails

        provideTitleViewModel()
        provideRequestedAmount()
        provideFullDetailsViewModel()

        refreshIdentities()
    }

    func didReceiveAccountVotes(
        _ votes: ReferendumAccountVoteLocal?,
        votingDistribution _: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    ) {
        accountVotes = votes

        provideYourVote()
    }

    func didReceiveMetadata(_ referendumMetadata: ReferendumMetadataLocal?) {
        self.referendumMetadata = referendumMetadata

        provideTitleViewModel()
        provideTimelineViewModel()
        provideFullDetailsViewModel()

        refreshIdentities()
    }

    func didReceiveIdentities(_ identities: [AccountAddress: AccountIdentity]) {
        self.identities = identities

        provideTitleViewModel()
    }

    func didReceiveRequestedAmountPrice(_ price: PriceData?) {
        requestedAmountPrice = price

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

    func didReceiveDApps(_ dApps: [GovernanceDApps.DApp]) {
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
                self?.refreshIdentities()
            }
        case .blockTimeFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshBlockTime()
            }
        case .dAppsFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeDAppsSubscription()
            }
        }
    }
}

// MARK: CountdownTimerDelegate

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

// MARK: Localizable

extension ReferendumDetailsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
