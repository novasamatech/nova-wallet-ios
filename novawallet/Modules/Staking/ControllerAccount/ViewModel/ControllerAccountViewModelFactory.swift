import NovaCrypto
import Foundation_iOS
import SubstrateSdk

final class ControllerAccountViewModelFactory: ControllerAccountViewModelFactoryProtocol {
    let selectedAddress: AccountAddress

    private lazy var accountViewModelFactory = WalletAccountViewModelFactory()

    init(selectedAddress: AccountAddress) {
        self.selectedAddress = selectedAddress
    }

    func createViewModel(
        stashItem: StashItem,
        stashAccountItem: MetaChainAccountResponse?,
        chosenAccountItem: MetaChainAccountResponse?,
        isDeprecated: Bool
    ) -> ControllerAccountViewModel {
        let stashAddress = stashItem.stash
        let stashViewModel: WalletAccountViewModel

        if let stashAccountItem = stashAccountItem {
            stashViewModel = (try? accountViewModelFactory.createViewModel(from: stashAccountItem))
                ?? .empty
        } else {
            stashViewModel = (try? accountViewModelFactory.createViewModel(from: stashAddress))
                ?? .empty
        }

        let selectedControllerAddress = stashItem.controller
        let controllerViewModel: WalletAccountViewModel

        if let controllerAccountItem = chosenAccountItem {
            controllerViewModel = (try? accountViewModelFactory.createViewModel(from: controllerAccountItem))
                ?? .empty
        } else {
            controllerViewModel = (try? accountViewModelFactory.createViewModel(from: selectedControllerAddress))
                ?? .empty
        }

        let currentAccountIsController =
            (stashItem.stash != stashItem.controller) &&
            stashItem.controller == selectedAddress

        let hasChangesToSave: Bool = {
            if isDeprecated, stashItem.stash != stashItem.controller {
                // we always allow to reset controller to stash
                return true
            }

            if stashAddress != selectedAddress {
                return false
            }

            guard let chosenAccountItem = chosenAccountItem else {
                return false
            }

            if chosenAccountItem.chainAccount.toAddress() == stashItem.controller {
                return false
            }

            return true
        }()

        return ControllerAccountViewModel(
            stashViewModel: stashViewModel,
            controllerViewModel: controllerViewModel,
            currentAccountIsController: currentAccountIsController,
            isDeprecated: isDeprecated,
            hasChangesToSave: hasChangesToSave
        )
    }
}
