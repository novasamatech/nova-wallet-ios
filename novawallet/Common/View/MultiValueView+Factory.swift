import Foundation
import UIKit

extension MultiValueView {
    static func createTableHeaderView() -> MultiValueView {
        let horInset = UIConstants.horizontalInset
        let margins = UIEdgeInsets(top: 16.0, left: horInset, bottom: 12.0, right: horInset)
        return createTableHeaderView(with: margins)
    }

    static func createTableHeaderView(with margins: UIEdgeInsets) -> MultiValueView {
        let view = MultiValueView()
        view.stackView.layoutMargins = margins
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.spacing = 8.0

        view.valueTop.numberOfLines = 0
        view.valueTop.textColor = R.color.colorWhite()
        view.valueTop.font = .boldTitle2
        view.valueTop.textAlignment = .left

        view.valueBottom.numberOfLines = 0
        view.valueBottom.textColor = R.color.colorTransparentText()
        view.valueBottom.font = .regularFootnote
        view.valueBottom.textAlignment = .left

        return view
    }
}
