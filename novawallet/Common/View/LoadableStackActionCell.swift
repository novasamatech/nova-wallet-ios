import Foundation
import UIKit

final class LoadableStackActionCell<TitleView: UIView>: RowView<LoadableStackActionView<TitleView>> {
    func startLoading() {
        rowContentView.startLoading()
    }

    func stopLoading() {
        rowContentView.stopLoading()
    }
}

extension LoadableStackActionCell {
    static func createSingleCell() -> LoadableStackActionCell<TitleView> {
        let cell = LoadableStackActionCell<TitleView>()
        cell.preferredHeight = 48.0
        cell.contentInsets = UIEdgeInsets(top: 0.0, left: 12.0, bottom: 0.0, right: 12.0)
        cell.roundedBackgroundView.cornerRadius = 12.0
        cell.roundedBackgroundView.roundingCorners = .allCorners
        cell.roundedBackgroundView.fillColor = R.color.colorWhite8()!
        cell.roundedBackgroundView.highlightedFillColor = R.color.colorHighlightedAccent()!
        cell.borderView.borderType = []
        return cell
    }
}

extension LoadableStackActionCell where TitleView: UILabel {
    func applyDefaultTitleStyle() {
        rowContentView.titleView.textColor = R.color.colorWhite()
        rowContentView.titleView.font = .regularSubheadline
    }
}
