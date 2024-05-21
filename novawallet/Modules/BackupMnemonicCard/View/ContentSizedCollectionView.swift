import UIKit

class ContentSizedCollectionView: UICollectionView {
    var onIntrinsicContentSizeInvalidate: (() -> Void)?

    override var contentSize: CGSize {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    override func reloadData() {
        super.reloadData()
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        contentSize
    }

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()

        onIntrinsicContentSizeInvalidate?()
    }
}
