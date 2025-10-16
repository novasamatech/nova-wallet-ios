import Foundation
import Foundation_iOS

final class WalletManagePresenter: WalletsListPresenter {
    enum AddWalletOptions: Int {
        case addNew
        case importExisting
    }

    var view: WalletManageViewProtocol? {
        baseView as? WalletManageViewProtocol
    }

    var interactor: WalletManageInteractorInputProtocol? {
        baseInteractor as? WalletManageInteractorInputProtocol
    }

    var wireframe: WalletManageWireframeProtocol? {
        baseWireframe as? WalletManageWireframeProtocol
    }

    private var cloudBackupState: CloudBackupSyncState?

    init(
        interactor: WalletManageInteractorInputProtocol,
        wireframe: WalletManageWireframeProtocol,
        viewModelFactory: WalletsListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        super.init(
            baseInteractor: interactor,
            baseWireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    private func askAndPerformRemoveItem(at index: Int, section: Int, completion: @escaping (Bool) -> Void) {
        let locale = localizationManager?.selectedLocale

        let removeTitle = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.accountDeleteConfirm()

        let removeAction = AlertPresentableAction(title: removeTitle, style: .destructive) { [weak self] in
            self?.performRemoveItem(at: index, section: section)

            completion(true)
        }

        let cancelTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()
        let cancelAction = AlertPresentableAction(title: cancelTitle, style: .cancel) {
            completion(false)
        }

        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.walletDeleteConfirmationTitle()
        let details = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.walletDeleteConfirmationDescription()
        let viewModel = AlertPresentableViewModel(
            title: title,
            message: details,
            actions: [cancelAction, removeAction],
            closeAction: nil
        )

        wireframe?.present(viewModel: viewModel, style: .alert, from: baseView)
    }

    private func performRemoveItem(at index: Int, section: Int) {
        var sectionViewModels = viewModels[section].items

        let viewModel = sectionViewModels.remove(at: index)
        replaceViewModels(sectionViewModels, section: section)

        if let item = walletsList.allItems.first(where: { $0.identifier == viewModel.identifier }) {
            interactor?.remove(item: item)
        }
    }

    private func showAddWallet() {
        if let cloudBackupState, cloudBackupState.canAutoSync {
            wireframe?.showCloudBackupRemind(from: view) { [weak self] in
                self?.wireframe?.showCreateWalletWithCloudBackup(from: self?.view)
            }
        } else {
            wireframe?.showCreateWalletWithManualBackup(from: view)
        }
    }

    private func showImportWallet() {
        if let cloudBackupState, cloudBackupState.canAutoSync {
            wireframe?.showCloudBackupRemind(from: view) { [weak self] in
                self?.wireframe?.showImportWallet(from: self?.view)
            }
        } else {
            wireframe?.showImportWallet(from: view)
        }
    }
}

extension WalletManagePresenter: WalletManagePresenterProtocol {
    func canDeleteItem(at _: Int, section: Int) -> Bool {
        guard viewModels.count > section else {
            return false
        }

        let nonRemovableTypes: [WalletsListSectionViewModel.SectionType] = [
            .proxied,
            .multisig
        ]

        return nonRemovableTypes.allSatisfy { $0 != viewModels[section].type }
    }

    func selectItem(at index: Int, section: Int) {
        let identifier = viewModels[section].items[index].identifier

        guard let wallet = walletsList.allItems.first(where: { $0.identifier == identifier }) else {
            return
        }

        wireframe?.showWalletDetails(from: view, metaAccount: wallet.info)
    }

    func moveItem(at startIndex: Int, to finalIndex: Int, section: Int) {
        guard startIndex != finalIndex else {
            return
        }

        var newItems = viewModels[section].items

        var saveItems: [ManagedMetaAccountModel]

        if startIndex > finalIndex {
            saveItems = newItems[finalIndex ... startIndex].map { viewModel in
                walletsList.allItems.first { $0.identifier == viewModel.identifier }!
            }
        } else {
            saveItems = newItems[startIndex ... finalIndex].map { viewModel in
                walletsList.allItems.first { $0.identifier == viewModel.identifier }!
            }.reversed()
        }

        let targetViewModel = newItems.remove(at: startIndex)
        newItems.insert(targetViewModel, at: finalIndex)

        let initialOrder = saveItems[0].order

        for index in 0 ..< saveItems.count - 1 {
            saveItems[index] = saveItems[index].replacingOrder(saveItems[index + 1].order)
        }

        let lastIndex = saveItems.count - 1
        saveItems[lastIndex] = saveItems[lastIndex].replacingOrder(initialOrder)

        interactor?.save(items: saveItems)
    }

    func removeItem(at index: Int, section: Int) {
        if let cloudBackupState, cloudBackupState.canAutoSync {
            wireframe?.showRemoveCloudBackupWalletWarning(from: view) { [weak self] in
                self?.performRemoveItem(at: index, section: section)
                self?.view?.didRemoveItem(at: index, section: section)
            }
        } else {
            askAndPerformRemoveItem(at: index, section: section) { [weak self] result in
                if result {
                    self?.view?.didRemoveItem(at: index, section: section)
                }
            }
        }
    }

    func activateAddWallet() {
        guard let view = view else {
            return
        }

        let createAction: LocalizableResource<ActionManageViewModel> = LocalizableResource { locale in
            let title = R.string(preferredLanguages: locale.rLanguages).localizable.onboardingCreateWallet()

            return ActionManageViewModel(icon: R.image.iconCircleOutline(), title: title, details: nil)
        }

        let importAction: LocalizableResource<ActionManageViewModel> = LocalizableResource { locale in
            let title = R.string(preferredLanguages: locale.rLanguages).localizable.walletImportExisting()

            return ActionManageViewModel(icon: R.image.iconImportWallet(), title: title, details: nil)
        }

        let context = ModalPickerClosureContext { [weak self] index in
            switch AddWalletOptions(rawValue: index) {
            case .addNew:
                self?.showAddWallet()
            case .importExisting:
                self?.showImportWallet()
            case .none:
                break
            }
        }

        wireframe?.presentActionsManage(
            from: view,
            actions: [createAction, importAction],
            title: LocalizableResource(
                closure: { locale in
                    R.string(preferredLanguages: locale.rLanguages).localizable.walletHowAdd()
                }
            ),
            delegate: self,
            context: context
        )
    }
}

extension WalletManagePresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let context = context as? ModalPickerClosureContext else {
            return
        }

        context.process(selectedIndex: index)
    }
}

extension WalletManagePresenter: WalletManageInteractorOutputProtocol {
    func didRemoveAllWallets() {
        wireframe?.showOnboarding(from: view)
    }

    func didReceiveCloudBackup(state: CloudBackupSyncState) {
        cloudBackupState = state
    }
}
