import UIKit
import SoraUI

final class ModalSheetCollectionViewDelegate: NSObject, UICollectionViewDelegate, ModalSheetPresenterDelegate {
    private let selectItemClosure: ((IndexPath) -> Void)?
    private weak var collectionView: UICollectionView?

    init(
        collectionView _: UICollectionView,
        selectItemClosure: ((IndexPath) -> Void)? = nil
    ) {
        self.selectItemClosure = selectItemClosure
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        selectItemClosure?(indexPath)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollView.bounces = scrollView.contentOffset.y > UIConstants.bouncesOffset
    }

    func presenterCanDrag(_: ModalPresenterProtocol) -> Bool {
        guard let collectionView = collectionView else {
            return true
        }
        let offset = collectionView.contentOffset.y + collectionView.contentInset.top
        return offset == 0
    }
}
