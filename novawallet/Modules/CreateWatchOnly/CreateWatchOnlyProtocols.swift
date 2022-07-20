protocol CreateWatchOnlyViewProtocol: ControllerBackedProtocol {}

protocol CreateWatchOnlyPresenterProtocol: AnyObject {
    func setup()
    func performContinue()
    func performSubstrateScan()
    func performEVMScan()
    func updateWalletNickname(_ partialNickname: String)
    func updateSubstrateAddress(_ partialAddress: String)
    func updateEVMAddress(_ partialAddress: String)
}

protocol CreateWatchOnlyInteractorInputProtocol: AnyObject {}

protocol CreateWatchOnlyInteractorOutputProtocol: AnyObject {}

protocol CreateWatchOnlyWireframeProtocol: AnyObject {}
