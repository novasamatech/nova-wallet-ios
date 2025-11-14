import Foundation
import UIKit

struct DisplayAddressViewModel {
    let address: String
    let name: String?
    let imageViewModel: ImageViewModelProtocol?
}

extension DisplayAddressViewModel: Equatable, Hashable {
    static func == (
        lhs: DisplayAddressViewModel,
        rhs: DisplayAddressViewModel
    ) -> Bool {
        lhs.address == rhs.address && lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(address)
    }
}

extension DisplayAddressViewModel {
    var lineBreakMode: NSLineBreakMode {
        name != nil ? .byTruncatingTail : .byTruncatingMiddle
    }

    var cellViewModel: StackCellViewModel {
        let details: String

        if let name = name {
            details = name
        } else {
            details = address
        }

        return StackCellViewModel(
            details: details,
            imageViewModel: imageViewModel
        )
    }
}
