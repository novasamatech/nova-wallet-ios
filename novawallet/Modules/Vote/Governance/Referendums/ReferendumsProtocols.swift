import Foundation
import Operation_iOS

protocol ReferendumsViewProtocol: ControllerBackedProtocol {
    var presenter: ReferendumsPresenterProtocol? { get set }

    func didReceiveChainBalance(viewModel: SecuredViewModel<ChainBalanceViewModel>)
    func update(model: ReferendumsViewModel)
    func updateReferendums(time: [ReferendumIdLocal: StatusTimeViewModel?])
}

protocol ReferendumsPresenterProtocol: AnyObject, WalletNoAccountHandling {
    func select(referendumIndex: ReferendumIdLocal)
    func selectUnlocks()
    func selectDelegations()
    func selectSwipeGov()
    func showFilters()
    func showSearch()
}

protocol ReferendumsInteractorInputProtocol: AnyObject {
    func setup()
    func saveSelected(option: GovernanceSelectedOption)
    func becomeOnline()
    func putOffline()
    func refreshReferendums()
    func refreshUnlockSchedule(for tracksVoting: ReferendumTracksVotingDistribution, blockHash: Data?)
    func remakeSubscriptions()
    func retryBlockTime()
    func retryOffchainVotingFetch()
}

protocol ReferendumsInteractorOutputProtocol: AnyObject {
    func didReceiveReferendums(_ referendums: [ReferendumLocal])
    func didReceiveReferendumsMetadata(_ changes: [DataProviderChange<ReferendumMetadataLocal>])
    func didReceiveVoting(_ voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>)
    func didReceiveOffchainVoting(_ voting: GovernanceOffchainVotesLocal)
    func didReceiveSelectedOption(_ option: GovernanceSelectedOption)
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceiveBlockTime(_ blockTime: BlockTime)
    func didReceiveUnlockSchedule(_ unlockSchedule: GovernanceUnlockSchedule)
    func didReceiveSupportDelegations(_ supportsDelegations: Bool)
    func didReceiveSwipeGovEligible(_ referendums: Set<ReferendumIdLocal>)
    func didReceiveError(_ error: ReferendumsInteractorError)
}

protocol ReferendumsWireframeProtocol: WalletNoAccountHandlingWireframe, ErrorPresentable, CommonRetryable {
    func selectChain(
        from view: ControllerBackedProtocol?,
        delegate: GovernanceChainSelectionDelegate,
        chainId: ChainModel.Id?,
        governanceType: GovernanceType?
    )

    func showSwipeGov(from view: ControllerBackedProtocol?)

    func showReferendumDetails(from view: ControllerBackedProtocol?, initData: ReferendumDetailsInitData)

    func showUnlocksDetails(from view: ControllerBackedProtocol?, initData: GovernanceUnlockInitData)

    func showAddDelegation(from view: ControllerBackedProtocol?)
    func showYourDelegations(from view: ControllerBackedProtocol?)
    func showFilters(
        from view: ControllerBackedProtocol?,
        delegate: ReferendumsFiltersDelegate,
        filter: ReferendumsFilter
    )

    func showSearch(
        from view: ControllerBackedProtocol?,
        referendumsState: Observable<ReferendumsViewState>,
        delegate: ReferendumSearchDelegate?
    )

    func showWalletDetails(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel
    )
}
