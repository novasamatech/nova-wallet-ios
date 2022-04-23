import UIKit
import SoraUI

final class LinkCellView: GenericTitleValueView<UILabel, LinkView> {
    var actionButton: RoundedButton { valueView.actionButton }

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
    }

    private func configureStyle() {
        titleView.textColor = R.color.colorTransparentText()!
        titleView.font = .regularFootnote
    }
}
