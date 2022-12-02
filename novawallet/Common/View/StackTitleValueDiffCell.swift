import UIKit

final class StackTitleValueDiffCell: RowView<TitleValueDiffView>, StackTableViewCellProtocol {
    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
    }

    private func configureStyle() {
        rowContentView.applyDefaultStyle()

        preferredHeight = 44.0
        borderView.strokeColor = R.color.colorDivider()!

        isUserInteractionEnabled = false
    }
}
