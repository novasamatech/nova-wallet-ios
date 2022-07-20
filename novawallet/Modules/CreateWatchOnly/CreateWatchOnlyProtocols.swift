import SoraFoundation

protocol CreateWatchOnlyViewProtocol: ControllerBackedProtocol {
    func didReceiveNickname(viewModel: InputViewModelProtocol)
    func didReceiveSubstrateAddressState(viewModel: AccountFieldStateViewModel)
    func didReceiveSubstrateAddressInput(viewModel: InputViewModelProtocol)
    func didReceiveEVMAddressState(viewModel: AccountFieldStateViewModel)
    func didReceiveEVMAddressInput(viewModel: InputViewModelProtocol)
    func didReceivePreset(titles: [String])
}

protocol CreateWatchOnlyPresenterProtocol: AnyObject {
    func setup()
    func performContinue()
    func performSubstrateScan()
    func performEVMScan()
    func updateWalletNickname(_ partialNickname: String)
    func updateSubstrateAddress(_ partialAddress: String)
    func updateEVMAddress(_ partialAddress: String)
    func selectPreset(at index: Int)
}

protocol CreateWatchOnlyInteractorInputProtocol: AnyObject {
    func setup()
    func save(wallet: WatchOnlyWallet)
}

protocol CreateWatchOnlyInteractorOutputProtocol: AnyObject {
    func didReceivePreset(wallets: [WatchOnlyWallet])
}

protocol CreateWatchOnlyWireframeProtocol: AnyObject {}
