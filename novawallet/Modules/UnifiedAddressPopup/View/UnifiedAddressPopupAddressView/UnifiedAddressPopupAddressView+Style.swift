import Foundation
import UIKit

extension UnifiedAddressPopupAddressView {
    struct Style {
        let addressStyle: UILabel.Style
        let chipsStyle: BorderedLabelView.Style
    }
}

extension UnifiedAddressPopupAddressView.Style {
    static var newFormat: Self {
        .init(
            addressStyle: .footnotePrimary,
            chipsStyle: .new
        )
    }

    static var legacyFormat: Self {
        .init(
            addressStyle: .footnoteSecondary,
            chipsStyle: .legacy
        )
    }
}
