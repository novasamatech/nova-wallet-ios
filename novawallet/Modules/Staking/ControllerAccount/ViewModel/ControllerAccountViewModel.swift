import SoraFoundation

struct ControllerAccountViewModel {
    let stashViewModel: WalletAccountViewModel
    let controllerViewModel: WalletAccountViewModel
    let currentAccountIsController: Bool
    let actionButtonIsEnabled: Bool
}

extension ControllerAccountViewModel {
    var canChooseOtherController: Bool {
        !currentAccountIsController
    }
}
