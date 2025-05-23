import UIKit
import UIKit_iOS
import Foundation_iOS

final class WalletEmptyStateDataSource {
    var titleResource: LocalizableResource<String>?
    var imageForEmptyState: UIImage?
    var titleColorForEmptyState: UIColor? = R.color.colorTextSecondary()!
    var titleFontForEmptyState: UIFont? = UIFont.p2Paragraph
    var verticalSpacingForEmptyState: CGFloat? = 16.0
    var trimStrategyForEmptyState: EmptyStateView.TrimStrategy = .none

    init(titleResource: LocalizableResource<String>, image: UIImage? = nil) {
        self.titleResource = titleResource
        imageForEmptyState = image
    }
}

extension WalletEmptyStateDataSource: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        nil
    }

    var titleForEmptyState: String? {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        return titleResource?.value(for: locale)
    }
}

extension WalletEmptyStateDataSource: Localizable {
    func applyLocalization() {}
}
