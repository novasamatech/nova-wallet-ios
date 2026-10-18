import UIKit
import UIKit_iOS

final class StartStakingInfoViewLayout: ScrollableContainerLayoutView {
    let headerStyle: MultiColorTextStyle
    let paragraphStyle: MultiColorTextStyle
    var skeletonView: SkrullableView?

    var header: StackTableHeaderCell = .create {
        $0.titleLabel.textAlignment = .center
    }

    lazy var wikiView: UITextView = .create {
        $0.textAlignment = .center
        $0.font = .regularCallout
        $0.textColor = R.color.colorTextSecondary()
        $0.isScrollEnabled = false
        $0.backgroundColor = .clear
        $0.isEditable = false
        $0.textContainerInset = .zero
    }

    let captionLabel = UILabel(style: .footnoteSecondary, textAlignment: .center, numberOfLines: 0)

    lazy var termsView: UITextView = .create {
        $0.textAlignment = .center
        $0.font = .regularCallout
        $0.textColor = R.color.colorTextSecondary()
        $0.isScrollEnabled = false
        $0.backgroundColor = .clear
        $0.isEditable = false
        $0.textContainerInset = .zero
    }

    let footer: BlurBackgroundView = .create {
        $0.sideLength = 12
        $0.cornerCut = [.topLeft, .topRight]
        $0.borderWidth = Constants.footerBorderWidth
        $0.borderColor = R.color.colorContainerBorder()!
    }

    let actionView = LoadableActionView()

    let secondaryButton: TriangularedButton?

    let balanceLabel = UILabel(style: .regularSubhedlineSecondary, textAlignment: .center, numberOfLines: 1)
    var paragraphViews: [ParagraphView] = []

    lazy var footerContentView = UIView.vStack(spacing: Constants.footerSpacing, [
        actionView,
        secondaryButton,
        balanceLabel
    ].compactMap { $0 })

    var onAnnouncementLinkTap: (() -> Void)?

    private var announcementView: InlineAlertView?
    private var announcementViewModel: AnnouncementViewModel?
    private var appliedFooterExtra: CGFloat = 0

    init(
        headerStyle: MultiColorTextStyle,
        paragraphStyle: MultiColorTextStyle,
        hasSecondaryAction: Bool = false
    ) {
        self.headerStyle = headerStyle
        self.paragraphStyle = paragraphStyle
        secondaryButton = hasSecondaryAction ? Self.createSecondaryButton() : nil

        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        updateFooterHeightIfNeeded()

        super.layoutSubviews()

        if skeletonView != nil {
            updateLoadingState()
            skeletonView?.restartSkrulling()
        }
    }

    override func setupStyle() {
        super.setupStyle()

        actionView.actionButton.applyEnabledStyle(colored: headerStyle.accentTextColor)
    }

    override func setupLayout() {
        super.setupLayout()

        stackView.layoutMargins = Constants.containerInsets
        stackView.layoutMargins.bottom += secondaryActionHeight

        footer.addSubview(footerContentView)

        actionView.snp.makeConstraints {
            $0.height.equalTo(Constants.actionViewHeight)
        }

        if let secondaryButton {
            secondaryButton.snp.makeConstraints {
                $0.height.equalTo(Constants.actionViewHeight)
            }

            footerContentView.setCustomSpacing(Constants.secondaryActionSpacing, after: actionView)
        }

        footerContentView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(Constants.footerInsets)
        }

        addSubview(footer)
        footer.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(Constants.footerHeight + Constants.footerBorderWidth + secondaryActionHeight)
            $0.bottom.equalToSuperview().offset(Constants.footerBorderWidth)
        }
    }

    func updateContent(
        title: AccentTextModel,
        caption: String?,
        paragraphs: [ParagraphView.Model],
        wikiUrl: StartStakingUrlModel,
        termsUrl: StartStakingUrlModel
    ) {
        let arrangedSubviews = stackView.arrangedSubviews

        arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        stackView.spacing = Constants.containerSpacing

        set(title: title)
        set(caption: caption)
        set(paragraphs: paragraphs)
        setWiki(urlModel: wikiUrl)
        setTerms(urlModel: termsUrl)
    }

    func updateBalanceButton(text: String, locale: Locale) {
        balanceLabel.text = text
        actionView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingStartTitle()
    }

    func updateSecondaryButton(title: String) {
        secondaryButton?.imageWithTitleView?.title = title
        secondaryButton?.invalidateLayout()
    }

    func setAnnouncement(viewModel: AnnouncementViewModel?) {
        announcementViewModel = viewModel

        if let viewModel {
            let banner: InlineAlertView

            if let announcementView {
                banner = announcementView
            } else {
                banner = InlineAlertView()
                banner.onLinkTap = { [weak self] in
                    self?.onAnnouncementLinkTap?()
                }
                footerContentView.insertArrangedSubview(banner, at: 0)
                announcementView = banner
            }

            banner.bind(announcement: viewModel)
        } else {
            announcementView?.removeFromSuperview()
            announcementView = nil
        }

        setNeedsLayout()
    }

    private func updateFooterHeightIfNeeded() {
        let bannerHeight = announcementViewModel.map {
            InlineAlertView.estimatedHeight(
                for: $0,
                width: bounds.width - 2 * Constants.footerInsets.left
            )
        }

        let extra = bannerHeight.map { $0 + Constants.footerSpacing } ?? 0

        guard bounds.width > 0, abs(extra - appliedFooterExtra) > 0.5 else {
            return
        }

        appliedFooterExtra = extra

        if let bannerHeight, let announcementView {
            announcementView.snp.remakeConstraints { make in
                make.height.equalTo(bannerHeight)
            }
        }

        footer.snp.updateConstraints {
            $0.height.equalTo(Constants.footerHeight + Constants.footerBorderWidth + secondaryActionHeight + extra)
        }

        stackView.layoutMargins.bottom = Constants.containerInsets.bottom + secondaryActionHeight + extra
    }

    private var secondaryActionHeight: CGFloat {
        secondaryButton != nil ? Constants.actionViewHeight + Constants.secondaryActionSpacing : 0
    }

    private static func createSecondaryButton() -> TriangularedButton {
        let button = TriangularedButton()
        button.applySecondaryDefaultStyle()
        return button
    }

    private func set(title: AccentTextModel) {
        header.titleLabel.bind(model: title, with: headerStyle)
        header.titleLabel.numberOfLines = 0
        stackView.addArrangedSubview(header)
    }

    private func set(caption: String?) {
        guard let caption else {
            return
        }

        captionLabel.apply(text: caption, lineHeight: Constants.captionLineHeight)
        stackView.setCustomSpacing(Constants.captionSpacing, after: header)
        stackView.addArrangedSubview(captionLabel)
    }

    private func set(paragraphs: [ParagraphView.Model]) {
        paragraphs.forEach {
            let view = ParagraphView(frame: .zero)
            view.style = paragraphStyle
            view.bind(viewModel: $0)
            view.contentInsets = .zero
            paragraphViews.append(view)
            stackView.addArrangedSubview(view)
        }
    }

    private func setWiki(urlModel model: StartStakingUrlModel) {
        wikiView.bind(
            url: model.url,
            urlText: model.urlName,
            in: model.text,
            style: .regularCalloutSecondary,
            linkFont: .semiBoldCallout
        )
        addArrangedSubview(wikiView)
        stackView.setCustomSpacing(Constants.wikiAndTermsSpacing, after: wikiView)
    }

    private func setTerms(urlModel model: StartStakingUrlModel) {
        termsView.bind(
            url: model.url,
            urlText: model.urlName,
            in: model.text,
            style: .regularCalloutSecondary,
            linkFont: .semiBoldCallout
        )
        addArrangedSubview(termsView)
    }
}

extension StartStakingInfoViewLayout {
    enum Constants {
        static let footerHeight: CGFloat = 144
        static let footerContentSpace: CGFloat = 28
        static let footerSpacing: CGFloat = 12
        static let secondaryActionSpacing: CGFloat = 8
        static let footerInsets = UIEdgeInsets(top: 16, left: 16, bottom: 31, right: 16)
        static let containerInsets = UIEdgeInsets(
            top: 12,
            left: 16,
            bottom: footerHeight,
            right: 16
        )
        static let containerSpacing: CGFloat = 32
        static let wikiAndTermsSpacing: CGFloat = 16
        static let captionSpacing: CGFloat = 8
        static let captionLineHeight: CGFloat = 18
        static let actionViewHeight: CGFloat = UIConstants.actionHeight
        static let footerBorderWidth: CGFloat = 1
        static let linkChevronSize: CGFloat = 20.0
    }
}
