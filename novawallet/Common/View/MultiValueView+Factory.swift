import Foundation
import UIKit

extension MultiValueView {
    static func createTableHeaderView() -> MultiValueView {
        let view = MultiValueView()

        let horInset = UIConstants.horizontalInset
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: horInset, bottom: 12.0, right: horInset)
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
