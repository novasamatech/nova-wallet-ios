import UIKit

final class TitleDetailsSheetViewLayout: UIView {
    let titleLabel: UILabel = .create {
        $0.apply(style: .bottomSheetTitle)
        $0.numberOfLines = 0
    }

    let detailsLabel: UILabel = .create {
        $0.apply(style: .footnoteSecondary)
        $0.numberOfLines = 0
    }

    private lazy var contentView = UIView.vStack(spacing: 10, [titleLabel, detailsLabel])

    private var detailsLineHeight: CGFloat?
    private var actionsBottomInset: CGFloat = 16

    private(set) var mainActionButton: TriangularedButton?
    private(set) var secondaryActionButton: TriangularedButton?
    private(set) var buttonsStackView: UIStackView?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBottomSheetBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupButtonsStackViewIfNeeded() {
        guard buttonsStackView == nil else {
            return
        }

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        stackView.distribution = .fillEqually
        stackView.alignment = .fill
        stackView.spacing = 16.0

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-actionsBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        buttonsStackView = stackView
    }

    func setupMainActionButton() {
        setupButtonsStackViewIfNeeded()

        let button = TriangularedButton()
        button.applyDefaultStyle()

        buttonsStackView?.addArrangedSubview(button)

        mainActionButton = button
    }

    func setupSecondaryActionButton() {
        setupButtonsStackViewIfNeeded()

        let button = TriangularedButton()
        button.applySecondaryDefaultStyle()

        buttonsStackView?.insertArrangedSubview(button, at: 0)

        secondaryActionButton = button
    }

    func apply(style: Style) {
        titleLabel.apply(style: style.title)
        contentView.spacing = style.spacing
        detailsLineHeight = style.detailsLineHeight
        actionsBottomInset = style.actionsBottomInset

        buttonsStackView?.snp.updateConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-actionsBottomInset)
        }
    }

    func bind(details: String) {
        if let detailsLineHeight {
            detailsLabel.apply(text: details, lineHeight: detailsLineHeight)
        } else {
            detailsLabel.text = details
        }
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.top.equalToSuperview().inset(10)
        }
    }
}

extension TitleDetailsSheetViewLayout {
    struct Style {
        let title: UILabel.Style
        let detailsLineHeight: CGFloat
        let spacing: CGFloat
        let actionsBottomInset: CGFloat
    }

    func contentHeight(model: TitleDetailsSheetViewModel, locale: Locale) -> CGFloat {
        let titleHeight = height(for: titleLabel, with: model.title.value(for: locale))
        let messageHeight = height(
            for: detailsLabel,
            with: model.message.value(for: locale),
            lineHeight: detailsLineHeight
        )
        let topOffset: CGFloat = 10
        let hasAnyActionButton = model.mainAction != nil || model.secondaryAction != nil
        let buttonHeight: CGFloat = hasAnyActionButton ? UIConstants.actionHeight : 0
        return topOffset + titleHeight + contentView.spacing + messageHeight + buttonHeight + actionsBottomInset
    }

    private func height(for label: UILabel, with text: String, lineHeight: CGFloat? = nil) -> CGFloat {
        let width = UIScreen.main.bounds.width - UIConstants.horizontalInset * 2
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        var attributes: [NSAttributedString.Key: Any] = [.font: label.font as Any]

        if let lineHeight {
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = lineHeight
            paragraph.maximumLineHeight = lineHeight
            attributes[.paragraphStyle] = paragraph
        }

        let boundingBox = text.boundingRect(
            with: constraintRect,
            options: .usesLineFragmentOrigin,
            attributes: attributes,
            context: nil
        )
        return boundingBox.height
    }
}
