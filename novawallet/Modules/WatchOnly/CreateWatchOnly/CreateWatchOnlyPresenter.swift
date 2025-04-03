import Foundation
import Foundation_iOS
import SubstrateSdk

final class CreateWatchOnlyPresenter {
    weak var view: CreateWatchOnlyViewProtocol?
    let wireframe: CreateWatchOnlyWireframeProtocol
    let interactor: CreateWatchOnlyInteractorInputProtocol
    let logger: LoggerProtocol

    private var partialSubstrateAddress: AccountAddress?
    private var partialEvmAddress: AccountAddress?
    private var partialNickname: String?
    private var presets: [WatchOnlyWallet] = []

    private(set) lazy var iconGenerator = PolkadotIconGenerator()

    init(
        interactor: CreateWatchOnlyInteractorInputProtocol,
        wireframe: CreateWatchOnlyWireframeProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
    }

    private func getSubstrateAccountId() -> AccountId? {
        try? partialSubstrateAddress?.toSubstrateAccountId()
    }

    private func getEVMAccountId() -> AccountId? {
        try? partialEvmAddress?.toEthereumAccountId()
    }

    private func provideSubstrateAddressStateViewModel() {
        if
            let accountId = getSubstrateAccountId(),
            let icon = try? iconGenerator.generateFromAccountId(accountId) {
            let iconViewModel = DrawableIconViewModel(icon: icon)
            let viewModel = AccountFieldStateViewModel(icon: iconViewModel)
            view?.didReceiveSubstrateAddressState(viewModel: viewModel)
        } else {
            let viewModel = AccountFieldStateViewModel(icon: nil)
            view?.didReceiveSubstrateAddressState(viewModel: viewModel)
        }
    }

    private func provideSubstrateInputViewModel() {
        let value = partialSubstrateAddress ?? ""

        let inputViewModel = InputViewModel.createAccountInputViewModel(for: value)

        view?.didReceiveSubstrateAddressInput(viewModel: inputViewModel)
    }

    private func provideEVMAddressStateViewModel() {
        if
            let accountId = getEVMAccountId(),
            let icon = try? iconGenerator.generateFromAccountId(accountId) {
            let iconViewModel = DrawableIconViewModel(icon: icon)
            let viewModel = AccountFieldStateViewModel(icon: iconViewModel)
            view?.didReceiveEVMAddressState(viewModel: viewModel)
        } else {
            let viewModel = AccountFieldStateViewModel(icon: nil)
            view?.didReceiveEVMAddressState(viewModel: viewModel)
        }
    }

    private func provideEVMInputViewModel() {
        let value = partialEvmAddress ?? ""

        let inputViewModel = InputViewModel.createAccountInputViewModel(for: value, required: false)

        view?.didReceiveEVMAddressInput(viewModel: inputViewModel)
    }

    private func provideWalletNicknameViewModel() {
        let value = partialNickname ?? ""

        let inputViewModel = InputViewModel.createNicknameInputViewModel(for: value)

        view?.didReceiveNickname(viewModel: inputViewModel)
    }

    private func providePresetViewModel() {
        let viewModels = presets.map(\.name)
        view?.didReceivePreset(titles: viewModels)
    }

    private func provideFieldsViewModels() {
        provideWalletNicknameViewModel()
        provideSubstrateAddressStateViewModel()
        provideSubstrateInputViewModel()
        provideEVMAddressStateViewModel()
        provideEVMInputViewModel()
    }
}

extension CreateWatchOnlyPresenter: CreateWatchOnlyPresenterProtocol {
    func setup() {
        provideFieldsViewModels()
        providePresetViewModel()

        interactor.setup()
    }

    func performContinue() {
        guard let name = partialNickname else {
            return
        }

        guard
            getSubstrateAccountId() != nil,
            let substrateAddress = partialSubstrateAddress else {
            let languages = view?.selectedLocale.rLanguages
            wireframe.present(
                message: R.string.localizable.commonInvalidSubstrateAddress(preferredLanguages: languages),
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                from: view
            )

            return
        }

        let evmAddressEmpty = (partialEvmAddress ?? "").isEmpty
        if !evmAddressEmpty, getEVMAccountId() == nil {
            let languages = view?.selectedLocale.rLanguages
            wireframe.present(
                message: R.string.localizable.commonInvalidEvmAddress(preferredLanguages: languages),
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                from: view
            )
            return
        }

        let evmAddress = !evmAddressEmpty ? partialEvmAddress : nil

        let wallet = WatchOnlyWallet(name: name, substrateAddress: substrateAddress, evmAddress: evmAddress)
        interactor.save(wallet: wallet)
    }

    func performSubstrateScan() {
        wireframe.showAddressScan(
            from: view,
            delegate: self,
            context: NSNumber(value: true)
        )
    }

    func performEVMScan() {
        wireframe.showAddressScan(
            from: view,
            delegate: self,
            context: NSNumber(value: false)
        )
    }

    func updateWalletNickname(_ partialNickname: String) {
        self.partialNickname = partialNickname
    }

    func updateSubstrateAddress(_ partialAddress: String) {
        partialSubstrateAddress = partialAddress

        provideSubstrateAddressStateViewModel()
    }

    func updateEVMAddress(_ partialAddress: String) {
        partialEvmAddress = partialAddress

        provideEVMAddressStateViewModel()
    }

    func selectPreset(at index: Int) {
        let preset = presets[index]
        partialNickname = preset.name
        partialSubstrateAddress = preset.substrateAddress
        partialEvmAddress = preset.evmAddress

        provideFieldsViewModels()
    }
}

extension CreateWatchOnlyPresenter: CreateWatchOnlyInteractorOutputProtocol {
    func didReceivePreset(wallets: [WatchOnlyWallet]) {
        presets = wallets

        providePresetViewModel()
    }

    func didCreateWallet() {
        wireframe.proceed(from: view)
    }

    func didFailWalletCreation(with error: Error) {
        _ = wireframe.present(error: error, from: view, locale: view?.selectedLocale)
        logger.error("Did receiver error: \(error)")
    }
}

extension CreateWatchOnlyPresenter: AddressScanDelegate {
    func addressScanDidReceiveRecepient(address: AccountAddress, context: AnyObject?) {
        wireframe.hideAddressScan(from: view)

        guard let isSubstrate = (context as? NSNumber)?.boolValue else {
            return
        }

        if isSubstrate {
            partialSubstrateAddress = address

            provideSubstrateAddressStateViewModel()
            provideSubstrateInputViewModel()
        } else {
            partialEvmAddress = address

            provideEVMAddressStateViewModel()
            provideEVMInputViewModel()
        }
    }
}
