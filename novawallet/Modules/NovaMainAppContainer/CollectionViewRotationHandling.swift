import UIKit

protocol CollectionViewRotationHandling {
    var tabBar: MainTabBarProtocol? { get }
}

extension CollectionViewRotationHandling {
    func findCollectionView(in view: UIView) -> UICollectionView? {
        // BFS
        var queue = [UIView]()
        queue.append(view)

        while !queue.isEmpty {
            let view = queue.removeFirst()

            if let collectionView = view as? UICollectionView {
                return collectionView
            }

            queue.append(contentsOf: view.subviews)
        }

        return nil
    }

    func updateCollectionViewLayoutIfNeeded() {
        guard
            let topView = tabBar?.topViewController()?.view,
            let collectionView = findCollectionView(in: topView)
        else { return }

        UIView.performWithoutAnimation {
            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.layoutIfNeeded()
        }
    }
}
