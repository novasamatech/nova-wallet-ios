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

    private lazy var iconGenerator = PolkadotIconGenerator()

    init(
        chain: ChainModel,
        interactor: ReferendumDetailsInteractorInputProtocol,
        wireframe: ReferendumDetailsWireframeProtocol,
        referendumViewModelFactory: ReferendumsModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        referendumFormatter: LocalizableResource<NumberFormatter>,
        referendumStringsFactory: ReferendumDisplayStringFactoryProtocol,
        referendum: ReferendumLocal,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.referendumViewModelFactory = referendumViewModelFactory
        self.referendumStringsFactory = referendumStringsFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.referendumFormatter = referendumFormatter
        self.referendum = referendum
        self.chain = chain
        self.logger = logger
        self.localizationManager = localizationManager
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
        let accountIcon: DrawableIconViewModel?
        let accountDisplayName: String?

        if
            let proposer = referendum.proposer,
            let identities = identities,
            let address = try? proposer.toAddress(using: chain.chainFormat) {
            accountIcon = (try? iconGenerator.generateFromAccountId(proposer)).map {
                DrawableIconViewModel(icon: $0)
            }

            accountDisplayName = identities[address]?.displayName ?? address
        } else {
            accountIcon = nil
            accountDisplayName = nil
        }

        let detailsLength = referendumMetadata?.details.count ?? 0

        let shouldReadMore = detailsLength > Self.readMoreThreshold

        let viewModel = ReferendumDetailsTitleView.Model(
            accountIcon: accountIcon,
            accountName: accountDisplayName,
            title: referendumMetadata?.name ?? "",
            description: referendumMetadata?.details ?? "",
            shouldReadMore: shouldReadMore
        )

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

    private func updateView() {
        provideReferendumInfoViewModel()
        provideTitleViewModel()
        provideRequestedAmount()
        provideYourVote()
        provideVotingDetails()
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
    }

    func didReceiveAccountVotes(_ votes: ReferendumAccountVoteLocal?) {
        accountVotes = votes

        provideYourVote()
    }

    func didReceiveMetadata(_ referendumMetadata: ReferendumMetadataLocal?) {
        self.referendumMetadata = referendumMetadata

        provideTitleViewModel()
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

        provideVotingDetails()
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime

        provideVotingDetails()
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
        }
    }
}

extension ReferendumDetailsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
