import UIKit_iOS
import UIKit

protocol ModalSheetScrollViewProtocol: ModalSheetPresenterDelegate {
    var scrollView: UIScrollView { get }
}

extension ModalSheetScrollViewProtocol {
    func presenterCanDrag(_: ModalPresenterProtocol) -> Bool {
        let offset = scrollView.contentOffset.y + scrollView.contentInset.top
        return offset == 0
    }
}

final class ModalSheetCollectionViewDelegate: CollectionViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollView.bounces = scrollView.contentOffset.y > UIConstants.bouncesOffset
    }
}
