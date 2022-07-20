import Foundation

final class CreateWatchOnlyPresenter {
    weak var view: CreateWatchOnlyViewProtocol?
    let wireframe: CreateWatchOnlyWireframeProtocol
    let interactor: CreateWatchOnlyInteractorInputProtocol

    init(
        interactor: CreateWatchOnlyInteractorInputProtocol,
        wireframe: CreateWatchOnlyWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension CreateWatchOnlyPresenter: CreateWatchOnlyPresenterProtocol {
    func setup() {}

    func performContinue() {}

    func performSubstrateScan() {}

    func performEVMScan() {}

    func updateWalletNickname(_: String) {}

    func updateSubstrateAddress(_: String) {}

    func updateEVMAddress(_: String) {}
}

extension CreateWatchOnlyPresenter: CreateWatchOnlyInteractorOutputProtocol {}
