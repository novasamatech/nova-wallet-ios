import Foundation
import Foundation_iOS

final class GenericLedgerAddEvmPresenter {
    weak var view: GenericLedgerAccountSelectionViewProtocol?
    let wireframe: GenericLedgerAddEvmWireframeProtocol
    let interactor: GenericLedgerAddEvmInteractorInputProtocol
    let viewModelFactory: GenericLedgerAccountVMFactoryProtocol
    let deviceName: String
    let deviceModel: LedgerDeviceModel
    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol

    private var accounts: [GenericLedgerAccountModel] = []

    init(
        interactor: GenericLedgerAddEvmInteractorInputProtocol,
        wireframe: GenericLedgerAddEvmWireframeProtocol,
        deviceName: String,
        deviceModel: LedgerDeviceModel,
        viewModelFactory: GenericLedgerAccountVMFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.deviceName = deviceName
        self.deviceModel = deviceModel
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
        self.logger = logger
    }
}

private extension GenericLedgerAddEvmPresenter {
    private func provideWarningIfNeeded(for account: GenericLedgerAccountModel) {
        let hasMissingEvm = account.addresses.contains(where: { $0.scheme == .evm && $0.accountId == nil })

        if hasMissingEvm {
            let viewModel = TitleWithSubtitleViewModel(
                title: R.string.localizable.genericLedgerUpdateTitle(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ),
                subtitle: R.string.localizable.genericLedgerNoEvmMessage(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                )
            )

            view?.didReceive(warningViewModel: viewModel, canLoadMore: false)
        }
    }

    private func performLoadNext() {
        let index = accounts.count

        guard index <= UInt32.max else {
            return
        }

        view?.didStartLoading()

        interactor.loadAccounts(at: UInt32(index))
    }

    private func addAccountViewModel(for account: GenericLedgerAccountModel) {
        let viewModel = viewModelFactory.createViewModel(
            for: account,
            locale: localizationManager.selectedLocale
        )

        view?.didAddAccount(viewModel: viewModel)
    }

    private func performConfirmation(at index: UInt32) {
        guard
            let account = accounts.first(where: { $0.index == index }),
            let address = account.addresses.first(where: { $0.scheme == .evm })?.address else {
            return
        }

        interactor.confirm(index: index)

        wireframe.showAddressVerification(
            on: view,
            deviceName: deviceName,
            deviceModel: deviceModel,
            address: address
        ) { [weak self] in
            self?.interactor.cancelConfirmation()
        }
    }
}

extension GenericLedgerAddEvmPresenter: GenericLedgerAccountSelectionPresenterProtocol {
    func setup() {
        performLoadNext()
    }

    func selectAccount(in section: Int) {
        let index = accounts[section].index
        performConfirmation(at: index)
    }

    func selectAddress(in section: Int, at index: Int) {
        let model = accounts[section].addresses[index]

        guard
            let view,
            let address = model.address else {
            return
        }

        wireframe.presentHardwareAddressOptions(
            from: view,
            address: address,
            scheme: model.scheme,
            locale: localizationManager.selectedLocale
        )
    }

    func loadNext() {
        performLoadNext()
    }
}

extension GenericLedgerAddEvmPresenter: GenericLedgerAddEvmInteractorOutputProtocol {
    func didReceive(account: GenericLedgerAccountModel) {
        logger.debug("Did receive account: \(account)")

        if account.index == accounts.count {
            view?.didStopLoading()

            if accounts.isEmpty {
                provideWarningIfNeeded(for: account)
            }

            accounts.append(account)

            addAccountViewModel(for: account)
        }
    }

    func didUpdateWallet() {
        guard let view else {
            return
        }

        wireframe.closeMessageSheet(on: view)
        wireframe.proceed(on: view)
    }

    func didReceive(error: GenericLedgerAddEvmInteractorError) {
        logger.error("Error: \(error)")

        switch error {
        case .accountFailed:
            wireframe.presentRequestStatus(
                on: view,
                locale: localizationManager.selectedLocale
            ) { [weak self] in
                self?.performLoadNext()
            }
        case let .updateFailed(_, index):
            wireframe.presentRequestStatus(
                on: view,
                locale: localizationManager.selectedLocale
            ) { [weak self] in
                self?.performConfirmation(at: index)
            }
        }
    }
}
