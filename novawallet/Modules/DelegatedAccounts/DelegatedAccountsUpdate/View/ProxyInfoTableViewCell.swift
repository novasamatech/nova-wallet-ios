import UIKit_iOS

final class ProxyInfoTableViewCell: PlainBaseTableViewCell<ProxyInfoView> {
    var actionButton: RoundedButton { contentDisplayView.linkView.actionButton }

    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear
    }

    func bind(text: String, link: String) {
        contentDisplayView.bind(text: text, link: link)
    }
}

final class ProxyInfoView: GenericPairValueView<UILabel, GenericPairValueView<LinkView, FlexibleSpaceView>> {
    var infoLabel: UILabel { fView }
    var linkView: LinkView { sView.fView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
    }

    func setupStyle() {
        makeVertical()
        spacing = 8
        infoLabel.apply(style: .footnoteSecondary)
        infoLabel.numberOfLines = 0
        linkView.setContentHuggingPriority(.required, for: .horizontal)
        linkView.actionButton.imageWithTitleView?.contentMode = .left
        stackView.layoutMargins = .init(top: 0, left: 0, bottom: 8, right: 0)
        sView.makeHorizontal()
    }

    func bind(text: String, link: String) {
        infoLabel.text = text
        linkView.actionButton.imageWithTitleView?.title = link
    }

    static func defaultHeight(text: String, link: String) -> CGFloat {
        let textHeight = height(for: .regularFootnote, with: text)
        let linkHeight = height(for: .caption1, with: link)

        return textHeight + 16 + linkHeight
    }

    private static func height(for font: UIFont?, with text: String) -> CGFloat {
        guard let font = font else {
            return 0
        }

        let width = UIScreen.main.bounds.width - UIConstants.horizontalInset * 2
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = text.boundingRect(
            with: constraintRect,
            options: .usesLineFragmentOrigin,
            attributes: [.font: font],
            context: nil
        )
        return boundingBox.height
    }
}
