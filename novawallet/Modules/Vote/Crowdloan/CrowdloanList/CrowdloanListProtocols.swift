import Foundation
import Foundation_iOS
import Operation_iOS

protocol CrowdloansViewProtocol: AlertPresentable, ControllerBackedProtocol, LoadableViewProtocol {
    var presenter: CrowdloanListPresenterProtocol? { get set }

    func didReceive(chainInfo: SecuredViewModel<ChainBalanceViewModel>)
    func didReceive(listState: CrowdloansViewModel)
}

protocol CrowdloanListPresenterProtocol: AnyObject {
    func handleYourContributions()
}

protocol CrowdloanListInteractorInputProtocol: AnyObject {
    func setup()
    func saveSelected(chainModel: ChainModel)
}

protocol CrowdloanListInteractorOutputProtocol: AnyObject {
    func didReceiveContributions(_ changes: [DataProviderChange<CrowdloanContribution>])
    func didReceiveDisplayInfo(_ info: CrowdloanDisplayInfoDict)
    func didReceiveSelectedChain(_ chain: ChainModel)
    func didReceiveAccountBalance(_ balance: AssetBalance?)
    func didReceivePriceData(_ price: PriceData?)
    func didReceiveError(_ error: Error)
}

protocol CrowdloanListWireframeProtocol: AlertPresentable, NoAccountSupportPresentable, ErrorPresentable {
    func showYourContributions(
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        from view: ControllerBackedProtocol?
    )

    func selectChain(
        from view: ControllerBackedProtocol?,
        delegate: ChainAssetSelectionDelegate,
        selectedChainAssetId: ChainAssetId?
    )

    func showWalletDetails(from view: ControllerBackedProtocol?, wallet: MetaAccountModel)
}
