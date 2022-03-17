import Foundation
import UIKit

struct DisplayAddressViewModel {
    let address: String
    let name: String?
    let imageViewModel: ImageViewModelProtocol?
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

        return StackCellViewModel(details: details, imageViewModel: imageViewModel)
    }
}
