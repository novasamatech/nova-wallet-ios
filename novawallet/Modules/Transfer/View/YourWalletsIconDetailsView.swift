import UIKit

final class YourWalletsIconDetailsView: IconDetailsView {
    override var intrinsicContentSize: CGSize {
        let width = detailsLabel.intrinsicContentSize.width + spacing + iconWidth
        return .init(width: width, height: 34)
    }
}
