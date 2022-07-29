import Foundation
import SoraFoundation
import UIKit

enum ChainAddressDetailsIndicator {
    case navigation
    case none
}

struct ChainAddressDetailsAction {
    let title: LocalizableResource<String>
    let icon: UIImage?
    let indicator: ChainAddressDetailsIndicator
    let onSelection: () -> Void
}

struct ChainAddressDetailsModel {
    let address: AccountAddress?
    let chainName: String
    let chainIcon: URL
    let actions: [ChainAddressDetailsAction]
}

final class ChainAddressDetailsModelBuilder {
    let address: AccountAddress
    let chainName: String
    let chainIcon: URL

    private var actions: [ChainAddressDetailsAction] = []

    init(address: AccountAddress, chainName: String, chainIcon: URL) {
        self.address = address
        self.chainName = chainName
        self.chainIcon = chainIcon
    }

    func addAction(
        for title: LocalizableResource<String>,
        icon: UIImage?,
        indicator: ChainAddressDetailsIndicator,
        onSelection: @escaping () -> Void
    ) -> ChainAddressDetailsModelBuilder {
        actions.append(
            ChainAddressDetailsAction(
                title: title,
                icon: icon,
                indicator: indicator,
                onSelection: onSelection
            )
        )

        return self
    }

    func build() -> ChainAddressDetailsModel {
        ChainAddressDetailsModel(
            address: address,
            chainName: chainName,
            chainIcon: chainIcon,
            actions: actions
        )
    }
}
