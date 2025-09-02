import Foundation
import UIKit
import Foundation_iOS

struct ChainAddressDetailsViewModel {
    struct Action {
        let title: LocalizableResource<String>
        let icon: UIImage?
        let indicator: ChainAddressDetailsIndicator
    }

    enum Title {
        case network(NetworkViewModel)
        case text(LocalizableResource<String>)
    }

    let title: Title
    let address: DisplayAddressViewModel?
    let actions: [Action]
}
