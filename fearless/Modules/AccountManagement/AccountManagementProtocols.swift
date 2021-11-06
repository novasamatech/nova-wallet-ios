import Foundation
import RobinHood
import SoraFoundation

protocol AccountManagementViewProtocol: ControllerBackedProtocol {
    func reload()
    func set(nameViewModel: InputViewModelProtocol)
}

protocol AccountManagementPresenterProtocol: AnyObject {
    func setup()

    func numberOfSections() -> Int
    func numberOfItems(in section: Int) -> Int
    func item(at indexPath: IndexPath) -> ChainAccountViewModelItem
    func titleForSection(_ section: Int) -> LocalizableResource<String>
    func activateDetails(at indexPath: IndexPath)
    func selectItem(at indexPath: IndexPath)
    func finalizeName()
}

protocol AccountManagementInteractorInputProtocol: AnyObject {
    func setup(walletId: String)
    func save(name: String, walletId: String)
    func flushPendingName()
    func requestExportOptions(metaAccount: MetaAccountModel, chain: ChainModel)
}

protocol AccountManagementInteractorOutputProtocol: AnyObject {
    func didReceiveWallet(_ result: Result<MetaAccountModel?, Error>)
    func didReceiveChains(_ result: Result<[ChainModel.Id: ChainModel], Error>)
    func didSaveWalletName(_ result: Result<String, Error>)
    func didReceive(
        exportOptionsResult: Result<[ExportOption], Error>,
        metaAccount: MetaAccountModel,
        chain: ChainModel
    )
}

protocol AccountManagementWireframeProtocol: AlertPresentable, ErrorPresentable, WebPresentable, ModalAlertPresenting {
    func showCreateAccount(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainId: ChainModel.Id,
        isEthereumBased: Bool
    )

    func showImportAccount(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainId: ChainModel.Id,
        isEthereumBased: Bool
    )

    func showExportAccount(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        options: [ExportOption],
        locale: Locale?,
        from view: AccountManagementViewProtocol?
    )
}

protocol AccountManagementViewFactoryProtocol: AnyObject {
    static func createView(for walletId: String) -> AccountManagementViewProtocol?
}
