import UIKit
import Foundation

extension UICollectionView {
    func reloadData(with completion: @escaping () -> Void) {
        reloadData()

        DispatchQueue.main.async {
            completion()
        }
    }
}
