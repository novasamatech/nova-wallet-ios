import UIKit
import UIKit_iOS

class CollectionViewDelegate: NSObject, UICollectionViewDelegate {
    private let selectItemClosure: ((IndexPath) -> Void)?

    init(selectItemClosure: ((IndexPath) -> Void)? = nil) {
        self.selectItemClosure = selectItemClosure
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        selectItemClosure?(indexPath)
    }
}
