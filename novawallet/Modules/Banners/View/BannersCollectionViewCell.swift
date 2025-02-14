import UIKit

class BannersCollectionViewCell: CollectionViewContainerCell<UIView> {
    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            view.snp.updateConstraints {
                $0.edges.equalToSuperview().inset(contentInsets)
            }
        }
    }
}
