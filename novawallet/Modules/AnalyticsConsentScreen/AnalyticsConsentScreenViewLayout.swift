import UIKit
import SnapKit
import UIKit_iOS

final class AnalyticsConsentScreenViewLayout: UIView {
    let titleLabel: UILabel = .create { view in
        view.apply(style: .boldTitle2Primary)
        view.numberOfLines = 0
        view.textAlignment = .center
    }

    let detailsView = AnalyticsConsentDetailsView(style: .full)

    let agreeButton: TriangularedButton = .create { view in
        view.applyDefaultStyle()
    }

    let declineButton: TriangularedButton = .create { view in
        view.applySecondaryDefaultStyle()
    }

    private let scrollView: UIScrollView = .create { view in
        view.showsVerticalScrollIndicator = false
    }

    private let iconPlate: RoundedView = .create { view in
        view.fillColor = R.color.colorBlockBackground()!.withAlphaComponent(Constants.backgroundOpacity)
        view.cornerRadius = Constants.plateSize / 2
        view.shadowOpacity = 0
    }

    private let iconImageView: UIImageView = .create { view in
        view.image = R.image.iconAnalyticsPrivacyShield()
        view.contentMode = .scaleAspectFit
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyLocalization(locale: Locale) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.minimumLineHeight = Constants.titleLineHeight
        paragraphStyle.maximumLineHeight = Constants.titleLineHeight
        titleLabel.attributedText = NSAttributedString(
            string: strings.analyticsPromptTitle(),
            attributes: [.paragraphStyle: paragraphStyle, .font: UIFont.boldTitle2]
        )
        agreeButton.imageWithTitleView?.title = strings.analyticsPromptEnable()
        declineButton.imageWithTitleView?.title = strings.analyticsPromptDecline()
        agreeButton.invalidateLayout()
        declineButton.invalidateLayout()
        detailsView.applyLocalization(locale: locale)
    }
}

private extension AnalyticsConsentScreenViewLayout {
    func setupLayout() {
        let buttons = UIStackView(arrangedSubviews: [agreeButton, declineButton])
        buttons.axis = .vertical
        buttons.spacing = Constants.buttonSpacing
        addSubview(buttons)
        buttons.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.buttonInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(Constants.buttonInset)
        }
        [agreeButton, declineButton].forEach { button in
            button.snp.makeConstraints { make in
                make.height.equalTo(Constants.buttonHeight)
            }
        }

        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(buttons.snp.top).offset(-Constants.sectionSpacing)
        }

        let content = UIStackView(arrangedSubviews: [iconPlate, titleLabel, detailsView])
        content.axis = .vertical
        content.alignment = .center
        content.spacing = Constants.sectionSpacing
        content.setCustomSpacing(Constants.iconSpacing, after: iconPlate)
        content.setCustomSpacing(Constants.titleSpacing, after: titleLabel)
        scrollView.addSubview(content)
        content.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide).inset(UIEdgeInsets(
                top: Constants.topInset,
                left: Constants.contentInset,
                bottom: 0,
                right: Constants.contentInset
            ))
            make.width.equalTo(scrollView.frameLayoutGuide).offset(-2 * Constants.contentInset)
        }
        [titleLabel, detailsView].forEach { child in
            child.snp.makeConstraints { make in
                make.width.equalToSuperview()
            }
        }
        iconPlate.snp.makeConstraints { make in
            make.size.equalTo(Constants.plateSize)
        }
        iconPlate.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }
    }

    enum Constants {
        static let plateSize: CGFloat = 88
        static let iconSize: CGFloat = 40
        static let backgroundOpacity: CGFloat = 0.16
        static let topInset: CGFloat = 66
        static let contentInset: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let iconSpacing: CGFloat = 36
        static let titleSpacing: CGFloat = 12
        static let titleLineHeight: CGFloat = 28
        static let buttonInset: CGFloat = 16
        static let buttonHeight: CGFloat = 52
        static let buttonSpacing: CGFloat = 12
    }
}

final class AnalyticsConsentDetailsView: UIView {
    enum Style {
        case full
        case compact
    }

    var onPrivacyNotice: (() -> Void)?

    private let style: Style

    private let messageTextView: LegalConsentTextView = .create { view in
        view.isScrollEnabled = false
        view.isEditable = false
        view.isSelectable = true
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.textDragInteraction?.isEnabled = false
        view.linkTextAttributes = [
            .foregroundColor: R.color.colorTextPrimary()!,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
    }

    private let descriptionLabel: UILabel = .create { view in
        view.apply(style: .footnoteSecondary)
        view.numberOfLines = 0
    }

    private let cardView: RoundedView = .create { view in
        view.fillColor = R.color.colorBlockBackground()!
        view.cornerRadius = Constants.cornerRadius
        view.shadowOpacity = 0
    }

    private let privacyButton: UIButton = .create { view in
        view.contentHorizontalAlignment = .left
        view.titleLabel?.font = .semiBoldSubheadline
        view.setTitleColor(R.color.colorButtonTextAccent(), for: .normal)
    }

    private let privacyButtonContainer = UIView()

    private let factLabels: [UILabel] = (0 ..< Constants.factCount).map { _ in
        UILabel(style: .regularSubhedlinePrimary)
    }

    init(style: Style) {
        self.style = style
        super.init(frame: .zero)

        setupLayout()
        messageTextView.delegate = self
        privacyButton.addTarget(self, action: #selector(actionPrivacyNotice), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyLocalization(locale: Locale) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let notice = strings.commonPrivacyNotice()
        let message = strings.analyticsPromptMessage(notice)
        let attributedMessage = NSMutableAttributedString(attributedString: makeText(
            message,
            font: .regularSubheadline,
            lineHeight: Constants.fullLineHeight,
            alignment: .center
        ))
        let noticeRange = (message as NSString).range(of: notice, options: .backwards)
        attributedMessage.addAttribute(.link, value: "#privacy-notice", range: noticeRange)
        messageTextView.attributedText = attributedMessage

        descriptionLabel.attributedText = makeText(
            strings.analyticsPrivacyDescription(),
            font: .regularFootnote,
            lineHeight: Constants.compactLineHeight
        )
        privacyButton.setAttributedTitle(makeText(
            notice,
            font: .semiBoldSubheadline,
            lineHeight: Constants.fullLineHeight,
            color: R.color.colorButtonTextAccent()!
        ), for: .normal)

        let facts = [
            strings.analyticsDetailsAddresses(),
            strings.analyticsDetailsIdentifiers(),
            strings.analyticsDetailsIp(),
            strings.analyticsDetailsSettings()
        ]
        zip(factLabels, facts).forEach { label, text in
            label.attributedText = makeText(
                text,
                font: style == .full ? .regularSubheadline : .regularFootnote,
                lineHeight: style == .full ? Constants.fullLineHeight : Constants.compactLineHeight,
                color: style == .full ? R.color.colorTextPrimary()! : R.color.colorTextSecondary()!
            )
        }
    }
}

private extension AnalyticsConsentDetailsView {
    func setupLayout() {
        if style == .full {
            cardView.fillColor = R.color.colorBlockBackground()!.withAlphaComponent(Constants.backgroundOpacity)
        }

        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = style == .full ? Constants.fullRowSpacing : Constants.compactRowSpacing
        factLabels.forEach { label in
            let icon = UIImageView(image: R.image.iconAnalyticsPrivacyCheckmark())
            icon.contentMode = .scaleAspectFit
            let row = UIStackView(arrangedSubviews: [icon, label])
            row.axis = .horizontal
            row.alignment = .top
            row.spacing = style == .full ? Constants.rowContentSpacing : Constants.compactRowContentSpacing
            icon.snp.makeConstraints { make in
                make.size.equalTo(style == .full ? Constants.fullIconSize : Constants.compactIconSize)
            }
            rows.addArrangedSubview(row)
        }

        descriptionLabel.isHidden = style == .full
        let cardContent = UIStackView(arrangedSubviews: [descriptionLabel, rows])
        cardContent.axis = .vertical
        cardContent.spacing = style == .full ? Constants.cardInset : Constants.compactRowSpacing
        cardView.addSubview(cardContent)
        cardContent.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.cardInset)
            make.top.bottom.equalToSuperview().inset(
                style == .full ? Constants.cardInset : Constants.compactCardVerticalInset
            )
        }

        messageTextView.isHidden = style == .compact
        privacyButtonContainer.isHidden = style == .full
        privacyButtonContainer.addSubview(privacyButton)
        privacyButton.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(Constants.linkInset)
        }

        let content = UIStackView(arrangedSubviews: [messageTextView, cardView, privacyButtonContainer])
        content.axis = .vertical
        content.spacing = style == .full ? Constants.fullSectionSpacing : Constants.compactRowSpacing
        addSubview(content)
        content.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        privacyButtonContainer.snp.makeConstraints { make in
            make.height.equalTo(Constants.linkHeight).priority(.high)
        }
    }

    func makeText(
        _ text: String,
        font: UIFont,
        lineHeight: CGFloat,
        alignment: NSTextAlignment = .left,
        color: UIColor = R.color.colorTextSecondary()!
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        return NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ])
    }

    @objc func actionPrivacyNotice() {
        onPrivacyNotice?()
    }

    enum Constants {
        static let factCount = 4
        static let backgroundOpacity: CGFloat = 0.16
        static let cornerRadius: CGFloat = 12
        static let cardInset: CGFloat = 16
        static let compactCardVerticalInset: CGFloat = 12
        static let fullIconSize: CGFloat = 24
        static let compactIconSize: CGFloat = 16
        static let fullLineHeight: CGFloat = 20
        static let compactLineHeight: CGFloat = 18
        static let rowContentSpacing: CGFloat = 12
        static let compactRowContentSpacing: CGFloat = 8
        static let fullRowSpacing: CGFloat = 14
        static let compactRowSpacing: CGFloat = 10
        static let fullSectionSpacing: CGFloat = 40
        static let linkHeight: CGFloat = 32
        static let linkInset: CGFloat = 4
    }
}

extension AnalyticsConsentDetailsView: UITextViewDelegate {
    func textView(
        _: UITextView,
        shouldInteractWith _: URL,
        in _: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        if interaction == .invokeDefaultAction {
            onPrivacyNotice?()
        }
        return false
    }
}
