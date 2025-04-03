import Foundation
import Foundation_iOS

final class UsernameSetupPresenter: BaseUsernameSetupPresenter {
    var wireframe: UsernameSetupWireframeProtocol

    init(wireframe: UsernameSetupWireframeProtocol) {
        self.wireframe = wireframe
    }
}

extension UsernameSetupPresenter: UsernameSetupPresenterProtocol {
    func proceed() {
        let walletName = viewModel.inputHandler.value
        wireframe.proceed(from: view, walletName: walletName)
    }
}
