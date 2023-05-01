import Foundation
import RobinHood

protocol ReferendumsViewProtocol: ControllerBackedProtocol {
    var presenter: ReferendumsPresenterProtocol? { get set }

    func didReceiveChainBalance(viewModel: ChainBalanceViewModel)
    func update(model: ReferendumsViewModel)
    func updateReferendums(time: [UInt: StatusTimeViewModel?])
}

protocol ReferendumsPresenterProtocol: AnyObject {
    func select(referendumIndex: UInt)
    func selectUnlocks()
    func selectDelegations()
    func showFilters()
    func showSearch()
}

protocol ReferendumsInteractorInputProtocol: BaseReferendumsInteractorInputProtocol {
    func saveSelected(option: GovernanceSelectedOption)
    func refreshUnlockSchedule(for tracksVoting: ReferendumTracksVotingDistribution, blockHash: Data?)
}

protocol ReferendumsInteractorOutputProtocol: AnyObject, BaseReferendumsInteractorOutputProtocol {
    func didReceiveSelectedOption(_ option: GovernanceSelectedOption)
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveUnlockSchedule(_ unlockSchedule: GovernanceUnlockSchedule)
    func didReceiveSupportDelegations(_ supportsDelegations: Bool)
}

protocol ReferendumsWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func selectChain(
        from view: ControllerBackedProtocol?,
        delegate: GovernanceAssetSelectionDelegate,
        chainId: ChainModel.Id?,
        governanceType: GovernanceType?
    )

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
        initialState: SearchReferndumsInitialState
    )
}
