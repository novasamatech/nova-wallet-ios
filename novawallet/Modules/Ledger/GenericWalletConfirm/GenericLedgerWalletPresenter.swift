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

    private var model: PolkadotLedgerWalletModel?

    init(
        deviceName: String,
        deviceModel: LedgerDeviceModel,
        appName: String,
        interactor: GenericLedgerWalletInteractorInputProtocol,
        wireframe: GenericLedgerWalletWireframeProtocol,
        viewModelFactory: ChainAccountViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.deviceName = deviceName
        self.deviceModel = deviceModel
        self.appName = appName
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger

        super.init(viewModelFactory: viewModelFactory)

        self.localizationManager = localizationManager
    }

    func getAddressesToConfirm() -> [HardwareWalletAddressScheme: AccountAddress]? {
        guard let model else {
            return nil
        }

        var result: [HardwareWalletAddressScheme: AccountAddress] = [:]

        if let address = try? model.substrate.accountId.toAddressForHWScheme(.substrate) {
            result[.substrate] = address
        }

        if let evm = model.evm, let address = try? evm.address.toAddressForHWScheme(.evm) {
            result[.evm] = address
        }

        guard !result.isEmpty else {
            return nil
        }

        return result
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
        // TODO: Provide dictionary here
        guard let address = getAddressesToConfirm()?.first?.value else {
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
    func didReceive(model: PolkadotLedgerWalletModel) {
        self.model = model

        var newAddresses: [HardwareWalletAddressModel] = [
            HardwareWalletAddressModel(
                accountId: model.substrate.accountId,
                scheme: .substrate
            )
        ]

        if let evm = model.evm {
            newAddresses.append(
                HardwareWalletAddressModel(
                    accountId: evm.address,
                    scheme: .evm
                )
            )
        }

        provideViewModel()
    }

    func didReceiveAccountConfirmation() {
        guard let view, let model else {
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
        case let .fetchAccount(fetchError):
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
