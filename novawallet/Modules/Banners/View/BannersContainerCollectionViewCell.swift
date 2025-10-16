import Foundation
import UIKit
import UIKit_iOS

class BannersContainerCollectionViewCell: CollectionViewContainerCell<UIView> {
    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            view.snp.updateConstraints {
                $0.edges.equalToSuperview().inset(contentInsets)
            }
        }
    }
}
