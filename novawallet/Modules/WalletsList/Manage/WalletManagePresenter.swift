import Foundation
import SoraFoundation

final class WalletManagePresenter: WalletsListPresenter {
    var view: WalletManageViewProtocol? {
        baseView as? WalletManageViewProtocol
    }

    var interactor: WalletManageInteractorInputProtocol? {
        baseInteractor as? WalletManageInteractorInputProtocol
    }

    var wireframe: WalletManageWireframeProtocol? {
        baseWireframe as? WalletManageWireframeProtocol
    }

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

        let removeTitle = R.string.localizable
            .accountDeleteConfirm(preferredLanguages: locale?.rLanguages)

        let removeAction = AlertPresentableAction(title: removeTitle, style: .destructive) { [weak self] in
            self?.performRemoveItem(at: index, section: section)

            completion(true)
        }

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale?.rLanguages)
        let cancelAction = AlertPresentableAction(title: cancelTitle, style: .cancel) {
            completion(false)
        }

        let title = R.string.localizable
            .walletDeleteConfirmationTitle(preferredLanguages: locale?.rLanguages)
        let details = R.string.localizable
            .walletDeleteConfirmationDescription(preferredLanguages: locale?.rLanguages)
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
}

extension WalletManagePresenter: WalletManagePresenterProtocol {
    func canDeleteItem(at _: Int, section _: Int) -> Bool {
        true
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
        askAndPerformRemoveItem(at: index, section: section) { [weak self] result in
            if result {
                self?.view?.didRemoveItem(at: index, section: section)
            }
        }
    }

    func activateAddWallet() {
        wireframe?.showAddWallet(from: view)
    }
}

extension WalletManagePresenter: WalletManageInteractorOutputProtocol {
    func didRemoveAllWallets() {
        wireframe?.showOnboarding(from: view)
    }
}
