import Foundation
import Foundation_iOS
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
    struct Network {
        let chainName: String
        let chainIcon: URL?
    }

    enum Title {
        case network(Network)
        case text(LocalizableResource<String>)

        init(chain: ChainModel) {
            self = .network(.init(chainName: chain.name, chainIcon: chain.icon))
        }
    }

    let address: AccountAddress?
    let title: Title
    let actions: [ChainAddressDetailsAction]
}

final class ChainAddressDetailsModelBuilder {
    let address: AccountAddress
    let title: ChainAddressDetailsModel.Title

    private var actions: [ChainAddressDetailsAction] = []

    convenience init(address: AccountAddress, titleText: LocalizableResource<String>) {
        self.init(address: address, title: .text(titleText))
    }

    convenience init(address: AccountAddress, chainName: String, chainIcon: URL?) {
        self.init(
            address: address,
            title: .network(.init(chainName: chainName, chainIcon: chainIcon))
        )
    }

    init(address: AccountAddress, title: ChainAddressDetailsModel.Title) {
        self.address = address
        self.title = title
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
            title: title,
            actions: actions
        )
    }
}
