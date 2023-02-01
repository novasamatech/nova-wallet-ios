import Foundation
import SoraFoundation
import SubstrateSdk

final class ReferendumDetailsPresenter {
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
    let accountManagementFilter: AccountManagementFilterProtocol
    let wallet: MetaAccountModel

    let chain: ChainModel
    let governanceType: GovernanceType
    let logger: LoggerProtocol

    private var referendum: ReferendumLocal
    private var actionDetails: ReferendumActionLocal?
    private var accountVotes: ReferendumAccountVoteLocal?
    private var votingDistribution: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    private var offchainVoting: GovernanceOffchainVotesLocal.Single?
    private var referendumMetadata: ReferendumMetadataLocal?
    private var identities: [AccountAddress: AccountIdentity]?
    private var price: PriceData?
    private var blockNumber: BlockNumber?
    private var blockTime: BlockTime?
    private var dApps: [GovernanceDApps.DApp]?

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
        self.wallet = wallet
        self.governanceType = governanceType
        self.accountManagementFilter = accountManagementFilter
        self.referendumViewModelFactory = referendumViewModelFactory
        self.referendumStringsFactory = referendumStringsFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.referendumFormatter = referendumFormatter
        self.referendumTimelineViewModelFactory = referendumTimelineViewModelFactory
        self.referendumMetadataViewModelFactory = referendumMetadataViewModelFactory
        self.statusViewModelFactory = statusViewModelFactory
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        referendum = initData.referendum
        accountVotes = initData.accountVotes
        votingDistribution = initData.votesResult
        offchainVoting = initData.offchainVoting
        blockNumber = initData.blockNumber
        blockTime = initData.blockTime
        referendumMetadata = initData.metadata
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
        let viewModel: YourVoteRow.Model?

        if let accountVotes = accountVotes {
            viewModel = referendumStringsFactory.createDirectVotesViewModel(
                from: accountVotes,
                chain: chain,
                locale: selectedLocale
            )
        } else if let offchainVoting = offchainVoting {
            switch offchainVoting.voteType {
            case let .direct(directVote):
                viewModel = referendumStringsFactory.createDirectVotesViewModel(
                    from: directVote,
                    chain: chain,
                    locale: selectedLocale
                )
            case let .delegated(delegateVote):
                viewModel = referendumStringsFactory.createDelegateVotesViewModel(
                    from: delegateVote,
                    delegateName: offchainVoting.identity?.displayName ?? offchainVoting.metadata?.name,
                    chain: chain,
                    locale: selectedLocale
                )
            }
        } else {
            viewModel = nil
        }

        view?.didReceive(yourVoteModel: viewModel)
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

        if let beneficiary = actionDetails?.amountSpendDetails?.beneficiary.accountId {
            accountIds.insert(beneficiary)
        }

        if let proposer = referendumMetadata?.proposerAccountId(for: chain.chainFormat) {
            accountIds.insert(proposer)
        }

        interactor.refreshIdentities(for: accountIds)
    }
}

extension ReferendumDetailsPresenter: ReferendumDetailsPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()
    }

    func vote() {
        guard let view = view else {
            return
        }

        if wallet.fetch(for: chain.accountRequest()) != nil {
            let initData = ReferendumVotingInitData(
                votesResult: nil,
                blockNumber: blockNumber,
                blockTime: blockTime,
                referendum: referendum,
                lockDiff: nil
            )

            wireframe.showVote(from: view, referendum: referendum, initData: initData)
        } else if accountManagementFilter.canAddAccount(to: wallet, chain: chain) {
            let message = R.string.localizable.commonChainCrowdloanAccountMissingMessage(
                chain.name,
                preferredLanguages: selectedLocale.rLanguages
            )

            wireframe.presentAddAccount(
                from: view,
                chainName: chain.name,
                message: message,
                locale: selectedLocale
            ) { [weak self] in
                guard let wallet = self?.wallet else {
                    return
                }

                self?.wireframe.showWalletDetails(from: self?.view, wallet: wallet)
            }
        } else {
            wireframe.presentNoAccountSupport(
                from: view,
                walletType: wallet.type,
                chainName: chain.name,
                locale: selectedLocale
            )
        }
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

    func opeDApp(at index: Int) {
        guard
            let dApp = dApps?[index],
            let url = try? dApp.extractFullUrl(for: referendum.index, governanceType: governanceType) else {
            return
        }

        wireframe.showDApp(from: view, url: url)
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
}

extension ReferendumDetailsPresenter: ReferendumDetailsInteractorOutputProtocol {
    func didReceiveReferendum(_ referendum: ReferendumLocal) {
        self.referendum = referendum

        provideReferendumInfoViewModel()
        provideVotingDetails()
        provideTitleViewModel()
        updateTimerIfNeeded()

        refreshIdentities()
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
        votingDistribution: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    ) {
        accountVotes = votes
        self.votingDistribution = votingDistribution

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
