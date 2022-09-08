import SoraUI

protocol ModalSheetCollectionViewProtocol: ModalSheetPresenterDelegate {
    var collectionView: UICollectionView { get }
}

extension ModalSheetCollectionViewProtocol {
    func presenterCanDrag(_: ModalPresenterProtocol) -> Bool {
        let offset = collectionView.contentOffset.y + collectionView.contentInset.top
        return offset == 0
    }
}
