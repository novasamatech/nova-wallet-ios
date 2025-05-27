import Foundation
import Foundation_iOS
import Operation_iOS

final class GenericLedgerWalletPresenter: HardwareWalletAddressesPresenter {
    let wireframe: GenericLedgerWalletWireframeProtocol
    let interactor: GenericLedgerWalletInteractorInputProtocol
    let logger: LoggerProtocol
    let deviceName: String
    let deviceModel: LedgerDeviceModel
    let appName: String

    private var account: LedgerSubstrateAccount?

    init(
        deviceName: String,
        deviceModel: LedgerDeviceModel,
        appName: String,
        interactor: GenericLedgerWalletInteractorInputProtocol,
        wireframe: GenericLedgerWalletWireframeProtocol,
        viewModelFactory: ChainAccountViewModelFactoryProtocol,
        localizationManager _: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.deviceName = deviceName
        self.deviceModel = deviceModel
        self.appName = appName
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger

        super.init(viewModelFactory: viewModelFactory)
    }

    private func provideDescriptionViewModel() {
        let languages = selectedLocale.rLanguages
        let viewModel = TitleWithSubtitleViewModel(
            title: R.string.localizable.paritySignerAddressesTitle(preferredLanguages: languages),
            subtitle: ""
        )

        view?.didReceive(descriptionViewModel: viewModel)
    }

    private func confirmAccount() {
        guard let address = account?.address else {
            return
        }

        interactor.confirmAccount()

        wireframe.showAddressVerification(
            on: view,
            deviceName: deviceName,
            deviceModel: deviceModel,
            address: address
        ) { [weak self] in
            self?.interactor.cancelRequest()
        }
    }
}

extension GenericLedgerWalletPresenter: HardwareWalletAddressesPresenterProtocol {
    func setup() {
        provideDescriptionViewModel()
        interactor.setup()
    }

    func select(viewModel: ChainAccountViewModelItem) {
        performSelection(of: viewModel, wireframe: wireframe, locale: selectedLocale)
    }

    func proceed() {
        confirmAccount()
    }
}

extension GenericLedgerWalletPresenter: GenericLedgerWalletInteractorOutputProtocol {
    func didReceive(account: LedgerSubstrateAccount) {
        self.account = account
        accountId = try? account.address.toAccountId()

        provideViewModel()
    }

    func didReceiveAccountConfirmation(with model: SubstrateLedgerWalletModel) {
        guard let view else {
            return
        }

        wireframe.closeMessageSheet(on: view)
        wireframe.procced(from: view, walletModel: model)
    }

    func didReceiveChains(changes: [DataProviderChange<ChainModel>]) {
        chainList.apply(changes: changes)

        provideViewModel()
    }

    func didReceive(error: GenericWalletConfirmInteractorError) {
        logger.error("Error: \(error)")

        guard let view = view else {
            return
        }

        let retryClosure: () -> Void
        let internalError: Error

        switch error {
        case let .fetAccount(fetchError):
            internalError = fetchError

            retryClosure = { [weak self] in
                self?.interactor.fetchAccount()
            }
        case let .confirmAccount(confirmError):
            internalError = confirmError

            retryClosure = { [weak self] in
                self?.confirmAccount()
            }
        }

        if let ledgerError = internalError as? LedgerError {
            wireframe.presentLedgerError(
                on: view,
                error: ledgerError,
                context: LedgerErrorPresentableContext(
                    networkName: appName,
                    deviceModel: deviceModel,
                    migrationViewModel: nil
                ),
                callbacks: LedgerErrorPresentableCallbacks(
                    cancelClosure: {},
                    retryClosure: retryClosure
                )
            )
        } else {
            wireframe.presentRequestStatus(on: view, locale: selectedLocale, retryAction: retryClosure)
        }
    }
}

extension GenericLedgerWalletPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideDescriptionViewModel()
        }
    }
}
