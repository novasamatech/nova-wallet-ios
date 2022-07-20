import Foundation
import SoraFoundation
import SubstrateSdk

final class CreateWatchOnlyPresenter {
    weak var view: CreateWatchOnlyViewProtocol?
    let wireframe: CreateWatchOnlyWireframeProtocol
    let interactor: CreateWatchOnlyInteractorInputProtocol

    private var partialSubstrateAddress: AccountAddress?
    private var partialEvmAddress: AccountAddress?
    private var partialNickname: String?
    private var presets: [WatchOnlyWallet] = []

    private(set) lazy var iconGenerator = PolkadotIconGenerator()

    init(
        interactor: CreateWatchOnlyInteractorInputProtocol,
        wireframe: CreateWatchOnlyWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    private func getSubstrateAccountId() -> AccountId? {
        try? partialSubstrateAddress?.toAccountId()
    }

    private func getEVMAccountId() -> AccountId? {
        try? partialEvmAddress?.toAccountId()
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

    func performContinue() {}

    func performSubstrateScan() {}

    func performEVMScan() {}

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
}
