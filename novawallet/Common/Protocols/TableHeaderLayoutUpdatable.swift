import Foundation
import UIKit

protocol TableHeaderLayoutUpdatable {
    var bounds: CGRect { get }

    func updateTableHeaderLayout(_ headerView: UIView)
}

extension TableHeaderLayoutUpdatable {
    func updateTableHeaderLayout(_ headerView: UIView) {
        let height = headerView.systemLayoutSizeFitting(
            CGSize(width: bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        let size = CGSize(width: bounds.width, height: height)
        if size != headerView.frame.size {
            headerView.frame = CGRect(origin: .zero, size: size)
        }
    }
}
