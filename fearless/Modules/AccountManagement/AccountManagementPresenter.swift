import Foundation
import RobinHood
import IrohaCrypto
import SoraFoundation

final class AccountManagementPresenter {
    weak var view: AccountManagementViewProtocol?
    var wireframe: AccountManagementWireframeProtocol!
    var interactor: AccountManagementInteractorInputProtocol!

    let viewModelFactory: ChainAccountViewModelFactoryProtocol
    let logger: LoggerProtocol?

    private var wallet: MetaAccountModel?
    private var chains: [ChainModel.Id: ChainModel] = [:]
    private var viewModel: ChainAccountListViewModel = []

    init(
        viewModelFactory: ChainAccountViewModelFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.viewModelFactory = viewModelFactory
        self.logger = logger
    }

    private func copyAddress(_ address: String) {
        UIPasteboard.general.string = address

        let locale = localizationManager?.selectedLocale
        let title = R.string.localizable.commonCopied(preferredLanguages: locale?.rLanguages)
        wireframe.presentSuccessNotification(title, from: view)
    }

    private func updateViewModels() {
        guard let wallet = wallet else { return }

        viewModel = viewModelFactory.createViewModel(from: wallet, chains: chains, for: selectedLocale)
        view?.reload()
    }
}

extension AccountManagementPresenter: AccountManagementPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func numberOfSections() -> Int {
        viewModel.count
    }

    func numberOfItems(in section: Int) -> Int {
        viewModel[section].chainAccounts.count
    }

    func item(at indexPath: IndexPath) -> ChainAccountViewModelItem {
        let section = viewModel[indexPath.section]
        let viewModels = section.chainAccounts
        return viewModels[indexPath.row]
    }

    func titleForSection(_ section: Int) -> LocalizableResource<String> {
        viewModel[section].section.title
    }

    func selectItem(at indexPath: IndexPath) {
        let viewModel = viewModel[indexPath.section]
            .chainAccounts[indexPath.row]

        // TODO: Add item analysis logic here
        let address = viewModel.address ?? "" // TODO: Process non-existant accounts

        // Case 1: address not found
        let locale = localizationManager?.selectedLocale

        var title = address

        let offset = title.count / 2
        title.insert(
            contentsOf: String.returnKey,
            at: title.index(title.startIndex, offsetBy: offset)
        )

        var actions: [AlertPresentableAction] = []

        // TODO: display account address
//        let accountsTitle = R.string.localizable.profileAccountsTitle(preferredLanguages: locale?.rLanguages)
//        let accountAction = AlertPresentableAction(title: accountsTitle) { [weak self] in
//            self?.wireframe.showAccountDetails(from: self?.view)
//        }
//
//        actions.append(accountAction)

        let copyTitle = R.string.localizable
            .commonCopyAddress(preferredLanguages: locale?.rLanguages)
        let copyAction = AlertPresentableAction(title: copyTitle) { [weak self] in
            self?.copyAddress(address) // TODO: Pass real address here
        }

        actions.append(copyAction)

        if
            let url = Chain.kusama.polkascanAddressURL(address) {
            let polkascanTitle = R.string.localizable
                .transactionDetailsViewPolkascan(preferredLanguages: locale?.rLanguages)

            let polkascanAction = AlertPresentableAction(title: polkascanTitle) { [weak self] in
                if let view = self?.view {
                    self?.wireframe.showWeb(url: url, from: view, style: .automatic)
                }
            }

            actions.append(polkascanAction)
        }

        if
            let url = Chain.kusama.subscanAddressURL(address) // userSettings?.connection.type.chain.subscanAddressURL(address)
        {
            let subscanTitle = R.string.localizable
                .transactionDetailsViewSubscan(preferredLanguages: locale?.rLanguages)
            let subscanAction = AlertPresentableAction(title: subscanTitle) { [weak self] in
                if let view = self?.view {
                    self?.wireframe.showWeb(url: url, from: view, style: .automatic)
                }
            }

            actions.append(subscanAction)
        }

        let changeAccountTitle = R.string.localizable
            .accountActionsChangeTitle(preferredLanguages: locale?.rLanguages)
        let changeAccountAction = AlertPresentableAction(title: changeAccountTitle) { [weak self] in
            print("Change account")
            // TODO: display another actions view?
        }

        actions.append(changeAccountAction)

        let exportAccountTitle = R.string.localizable
            .commonExport(preferredLanguages: locale?.rLanguages)
        let exportAction = AlertPresentableAction(title: exportAccountTitle) { [weak self] in
            print("Export account")
            // TODO: display another actions view
        }

        actions.append(exportAction)

        let closeTitle = R.string.localizable
            .commonCancel(preferredLanguages: selectedLocale.rLanguages)

        let actionsViewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: actions,
            closeAction: closeTitle
        )

        wireframe.present(
            viewModel: actionsViewModel,
            style: .actionSheet,
            from: view
        )
    }
}

extension AccountManagementPresenter: AccountManagementInteractorOutputProtocol {
    func didReceiveWallet(_ wallet: MetaAccountModel) {
        self.wallet = wallet
        updateViewModels()
    }

    func didReceiveChains(_ result: Result<[ChainModel.Id: ChainModel], Error>) {
        switch result {
        case let .success(chains):
            self.chains = chains
            updateViewModels()

        case let .failure(error):
            logger?.error("Did receive chains fetch error: \(error)")
        }
    }
}

extension AccountManagementPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateViewModels()
        }
    }
}
