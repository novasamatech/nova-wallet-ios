import UIKit
import SoraUI

final class CollectionViewDelegate: NSObject, UICollectionViewDelegate {
    private let selectItemClosure: ((IndexPath) -> Void)?

    init(selectItemClosure: ((IndexPath) -> Void)? = nil) {
        self.selectItemClosure = selectItemClosure
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        selectItemClosure?(indexPath)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollView.bounces = scrollView.contentOffset.y > UIConstants.bouncesOffset
    }
}
