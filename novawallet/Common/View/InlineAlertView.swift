import UIKit
import UIKit_iOS

final class InlineAlertView: UIView {
    let backgroundView: RoundedView = {
        let view = RoundedView()
        view.applyFilledBackgroundStyle()
        view.cornerRadius = 10.0
        return view
    }()

    let contentView: IconDetailsView = {
        let view = IconDetailsView()
        view.mode = .iconDetails
        view.detailsLabel.numberOfLines = 0
        view.iconWidth = Constants.iconWidth
        view.detailsLabel.textColor = R.color.colorTextPrimary()
        view.detailsLabel.font = .caption1
        view.spacing = Constants.iconTextSpacing
        return view
    }()

    let linkButton: UIButton = {
        let button = UIButton()
        button.contentHorizontalAlignment = .leading
        button.isHidden = true
        return button
    }()

    /// Called when the user taps the link row bound through `setLink(title:)`.
    var onLinkTap: (() -> Void)?

    private let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .fill
        view.spacing = Constants.linkTopSpacing
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
        setupHandlers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(Constants.verticalContentInset)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalContentInset)
        }

        stackView.addArrangedSubview(contentView)

        let linkContainer = UIView()
        linkContainer.addSubview(linkButton)
        linkButton.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
            make.leading.equalToSuperview().offset(Constants.iconWidth + Constants.iconTextSpacing)
            make.height.equalTo(Constants.linkRowHeight)
        }

        stackView.addArrangedSubview(linkContainer)
        linkContainer.isHidden = true
    }

    private func setupHandlers() {
        linkButton.addTarget(self, action: #selector(actionLinkTap), for: .touchUpInside)
    }

    @objc private func actionLinkTap() {
        onLinkTap?()
    }
}

extension InlineAlertView {
    func apply(style: Style) {
        switch style {
        case .error:
            backgroundView.fillColor = R.color.colorErrorBlockBackground()!
            contentView.imageView.image = R.image.iconSlash()
        case .warning:
            backgroundView.fillColor = R.color.colorWarningBlockBackground()!
            contentView.imageView.image = R.image.iconWarning()
        case .info:
            backgroundView.fillColor = R.color.colorIndividualChipBackground()!
            contentView.imageView.image = R.image.iconInfoAccent()
        }

        contentView.stackView.alignment = .top
    }

    /// Shows a "Learn more ›" row under the message, or hides it when `title` is nil.
    func setLink(title: String?) {
        guard let title else {
            linkButton.isHidden = true
            linkButton.superview?.isHidden = true
            return
        }

        linkButton.bindLearnMore(learnMoreText: title, style: .caption1Secondary)
        linkButton.isHidden = false
        linkButton.superview?.isHidden = false
    }

    static func warning() -> InlineAlertView {
        let view = InlineAlertView()
        view.apply(style: .warning)
        return view
    }

    static func error() -> InlineAlertView {
        let view = InlineAlertView()
        view.apply(style: .error)
        return view
    }

    static func info() -> InlineAlertView {
        let view = InlineAlertView()
        view.apply(style: .info)
        return view
    }

    static func inline(for style: InlineAlertView.Style) -> InlineAlertView {
        switch style {
        case .error:
            return InlineAlertView.error()
        case .warning:
            return InlineAlertView.warning()
        case .info:
            return InlineAlertView.info()
        }
    }
}

extension InlineAlertView {
    enum Style {
        case error
        case warning
        case info
    }
}

extension InlineAlertView {
    enum Constants {
        static let horizontalContentInset: CGFloat = 16
        static let verticalContentInset: CGFloat = 10
        static let iconWidth: CGFloat = 16
        static let iconTextSpacing: CGFloat = 12
        static let linkRowHeight: CGFloat = 24
        static let linkTopSpacing: CGFloat = 4
    }

    static func estimatedHeight(for message: String, width: CGFloat, hasLink: Bool = false) -> CGFloat {
        let minHeight = Constants.iconWidth + 2 * Constants.verticalContentInset

        let textWidth = width - 2 * Constants.horizontalContentInset
            - Constants.iconWidth - Constants.iconTextSpacing

        let linkHeight = hasLink ? Constants.linkTopSpacing + Constants.linkRowHeight : 0

        guard textWidth > 0 else {
            return minHeight + linkHeight
        }

        let textHeight = message.estimateHeight(for: .caption1, width: textWidth)

        return max(ceil(textHeight) + 2 * Constants.verticalContentInset, minHeight) + linkHeight
    }
}
