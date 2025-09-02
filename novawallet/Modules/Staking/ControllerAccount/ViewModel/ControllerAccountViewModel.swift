import Foundation_iOS

struct ControllerAccountViewModel {
    let stashViewModel: WalletAccountViewModel
    let controllerViewModel: WalletAccountViewModel
    let currentAccountIsController: Bool
    let isDeprecated: Bool
    let hasChangesToSave: Bool

    var stashEqualsController: Bool {
        stashViewModel.address == controllerViewModel.address
    }

    var shouldHideActionButton: Bool {
        currentAccountIsController || (isDeprecated && stashEqualsController)
    }
}

extension ControllerAccountViewModel {
    var canChooseOtherController: Bool {
        !currentAccountIsController && !isDeprecated
    }
}
