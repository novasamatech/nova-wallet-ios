import UIKit
import SubstrateSdk

struct ManagedWalletViewModelItem: Equatable {
    let identifier: String
    let name: String
    let icon: DrawableIcon?
    let isSelected: Bool

    static func == (lhs: ManagedWalletViewModelItem, rhs: ManagedWalletViewModelItem) -> Bool {
        lhs.identifier == rhs.identifier &&
            lhs.name == rhs.name &&
            lhs.isSelected == rhs.isSelected
    }
}
