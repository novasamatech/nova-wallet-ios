import Foundation
import UIKit
import SoraFoundation

struct ChainAddressDetailsViewModel {
    struct Action {
        let title: LocalizableResource<String>
        let icon: UIImage?
        let indicator: ChainAddressDetailsIndicator
    }

    let address: DisplayAddressViewModel?
    let network: NetworkViewModel
    let actions: [Action]
}
