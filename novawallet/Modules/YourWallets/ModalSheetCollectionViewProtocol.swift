import SoraUI
import UIKit

protocol ModalSheetCollectionViewProtocol: ModalSheetPresenterDelegate {
    var collectionView: UICollectionView { get }
}

extension ModalSheetCollectionViewProtocol {
    func presenterCanDrag(_: ModalPresenterProtocol) -> Bool {
        let offset = collectionView.contentOffset.y + collectionView.contentInset.top
        return offset == 0
    }
}

final class ModalSheetCollectionViewDelegate: CollectionViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollView.bounces = scrollView.contentOffset.y > UIConstants.bouncesOffset
    }
}
