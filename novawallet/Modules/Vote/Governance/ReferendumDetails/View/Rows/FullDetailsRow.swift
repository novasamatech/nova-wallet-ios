import UIKit

final class FullDetailsRow: RowView<GenericTitleValueView<UILabel, UIImageView>> {
    let titleLabel = UILabel(style: .rowLink, textAlignment: .left)
    let arrowView = UIImageView(image: R.image.iconChevronRight())
    lazy var contentMultiValueView = GenericTitleValueView<UILabel, UIImageView>(
        titleView: titleLabel,
        valueView: arrowView
    )

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView = contentMultiValueView
        backgroundView = TriangularedBlurView()
        contentInsets = .init(top: 14, left: 16, bottom: 14, right: 16)
        preferredHeight = 52
        backgroundColor = .clear
    }

    func bind(title: String) {
        titleLabel.text = title
    }
}
