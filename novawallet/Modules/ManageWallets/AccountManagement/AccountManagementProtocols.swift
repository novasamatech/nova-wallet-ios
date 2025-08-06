import Foundation
import Operation_iOS
import Foundation_iOS

protocol AccountManagementViewProtocol: ControllerBackedProtocol {
    func reload()
    func didReceive(walletViewModel: AccountManageWalletViewModel)
    func didReceive(nameViewModel: InputViewModelProtocol)
}

protocol AccountManagementPresenterProtocol: AnyObject {
    func setup()

    func numberOfSections() -> Int
    func numberOfItems(in section: Int) -> Int
    func item(at indexPath: IndexPath) -> ChainAccountViewModelItem
    func titleForSection(_ section: Int) -> LocalizableResource<String>?
    func actionForSection(_ section: Int) -> LocalizableResource<IconWithTitleViewModel>?
    func activateDetails(at indexPath: IndexPath)
    func selectItem(at indexPath: IndexPath)
    func activateActionInSection(_ section: Int)
    func finalizeName()
}

protocol AccountManagementInteractorInputProtocol: AnyObject {
    func setup(walletId: String)
    func save(name: String, walletId: String)
    func flushPendingName()
    func requestExportOptions(metaAccount: MetaAccountModel, chain: ChainModel)
    func createAccount(for walletId: MetaAccountModel.Id, chain: ChainModel)
}

protocol AccountManagementInteractorOutputProtocol: AnyObject {
    func didReceiveWallet(_ result: Result<MetaAccountModel?, Error>)
    func didReceiveChains(_ result: Result<[ChainModel.Id: ChainModel], Error>)
    func didSaveWalletName(_ result: Result<String, Error>)
    func didReceive(
        exportOptionsResult: Result<[SecretSource], Error>,
        metaAccount: MetaAccountModel,
        chain: ChainModel
    )
    func didReceiveDelegateWallet(_ result: Result<MetaAccountModel?, Error>)
    func didReceiveCloudBackup(state: CloudBackupSyncState)
    func didReceiveAccountCreationResult(_ result: Result<Void, Error>, chain: ChainModel)
}

protocol AccountManagementWireframeProtocol: AlertPresentable,
    ErrorPresentable,
    WebPresentable,
    ModalAlertPresenting,
    ChainAddressDetailsPresentable,
    ActionsManagePresentable,
    CloudBackupRemindPresentable,
    CopyAddressPresentable,
    UnifiedAddressPopupPresentable,
    AddressOptionsPresentable
{
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

    func showChangeWatchOnlyAccount(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chain: ChainModel
    )

    func showExportAccount(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        options: [SecretSource],
        from view: AccountManagementViewProtocol?
    )

    func showAddLedgerAccount(
        from view: AccountManagementViewProtocol?,
        wallet: MetaAccountModel,
        chain: ChainModel
    )

    func showAddGenericLedgerEvmAccounts(
        from view: AccountManagementViewProtocol?,
        wallet: MetaAccountModel
    )
}

protocol AccountManagementViewFactoryProtocol: AnyObject {
    static func createView(for walletId: String) -> AccountManagementViewProtocol?
}
