import Foundation
import SoraUI

class BannersContainerCollectionViewCell: CollectionViewContainerCell<UIView> {
    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            view.snp.updateConstraints {
                $0.edges.equalToSuperview().inset(contentInsets)
            }
        }
    }
}
