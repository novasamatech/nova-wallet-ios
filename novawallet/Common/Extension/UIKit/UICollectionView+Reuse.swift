import UIKit

extension UICollectionView {
    func registerClass(_ viewClass: UICollectionReusableView.Type, forSupplementaryViewOfKind kind: String) {
        register(viewClass, forSupplementaryViewOfKind: kind, withReuseIdentifier: viewClass.reuseIdentifier)
    }

    func registerCellClass(_ viewClass: UICollectionReusableView.Type) {
        register(viewClass, forCellWithReuseIdentifier: viewClass.reuseIdentifier)
    }

    func dequeueReusableCellWithType<T: UICollectionViewCell>(_ viewClass: T.Type, for indexPath: IndexPath) -> T? {
        dequeueReusableCell(withReuseIdentifier: viewClass.reuseIdentifier, for: indexPath) as? T
    }

    func dequeueReusableSupplementaryViewWithType<T: UICollectionReusableView>(
        _ viewClass: T.Type,
        forSupplementaryViewOfKind kind: String,
        for indexPath: IndexPath
    ) -> T? {
        dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: viewClass.reuseIdentifier,
            for: indexPath
        ) as? T
    }
}
