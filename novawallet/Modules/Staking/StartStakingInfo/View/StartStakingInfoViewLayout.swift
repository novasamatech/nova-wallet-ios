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

    let balanceLabel = UILabel(style: .regularSubhedlineSecondary, textAlignment: .center, numberOfLines: 1)
    var paragraphViews: [ParagraphView] = []

    init(headerStyle: MultiColorTextStyle, paragraphStyle: MultiColorTextStyle) {
        self.headerStyle = headerStyle
        self.paragraphStyle = paragraphStyle

        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
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

        let footerContentView = UIView.vStack(spacing: Constants.footerSpacing, [
            actionView,
            balanceLabel
        ])
        footer.addSubview(footerContentView)

        actionView.snp.makeConstraints {
            $0.height.equalTo(Constants.actionViewHeight)
        }

        footerContentView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(Constants.footerInsets)
        }

        addSubview(footer)
        footer.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(Constants.footerHeight + Constants.footerBorderWidth)
            $0.bottom.equalToSuperview().offset(Constants.footerBorderWidth)
        }
    }

    func updateContent(
        title: AccentTextModel,
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

    private func set(title: AccentTextModel) {
        header.titleLabel.bind(model: title, with: headerStyle)
        header.titleLabel.numberOfLines = 0
        stackView.addArrangedSubview(header)
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

extension StartStakingInfoViewLayout: SkeletonableView {
    var skeletonSuperview: UIView {
        containerView
    }

    var hidingViews: [UIView] {
        [
            header,
            wikiView,
            termsView
        ] + paragraphViews
    }

    // swiftlint:disable:next function_body_length
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let offsetX: CGFloat = 18
        let offsetY: CGFloat = 39
        let spacing: CGFloat = 55
        let iconSize = CGSize(width: 28, height: 28)
        let titleSize = CGSize(width: 155, height: 10)
        let subtitleSize = CGSize(width: 126, height: 10)

        let headerFirstLineSize = CGSize(width: 145, height: 16)
        let headerSecondLineSize = CGSize(width: 185, height: 16)
        let headerThirdLineSize = CGSize(width: 109, height: 16)

        let topOffsetY = safeAreaInsets.top + 23

        let headerFirstLineOffset = CGPoint(
            x: spaceSize.width / 2 - headerFirstLineSize.width / 2,
            y: topOffsetY
        )

        let headerFirstLineSkeleton = SingleSkeleton.createRow(
            on: containerView,
            containerView: containerView,
            spaceSize: spaceSize,
            offset: headerFirstLineOffset,
            size: headerFirstLineSize
        )
        let headerSecondLineOffset = CGPoint(
            x: spaceSize.width / 2 - headerSecondLineSize.width / 2,
            y: headerFirstLineOffset.y + headerFirstLineSize.height + 17
        )
        let headerSecondLineSkeleton = SingleSkeleton.createRow(
            on: containerView,
            containerView: containerView,
            spaceSize: spaceSize,
            offset: headerSecondLineOffset,
            size: headerSecondLineSize
        )

        let headerThirdLineOffset = CGPoint(
            x: spaceSize.width / 2 - headerThirdLineSize.width / 2,
            y: headerSecondLineOffset.y + headerSecondLineSize.height + 17
        )
        let headerThirdLineSkeleton = SingleSkeleton.createRow(
            on: containerView,
            containerView: containerView,
            spaceSize: spaceSize,
            offset: headerThirdLineOffset,
            size: headerThirdLineSize
        )

        let compoundSkeletons: [[Skeletonable]] = (0 ..< 5).map { index in
            let iconOffset = CGPoint(
                x: offsetX,
                y: headerThirdLineOffset.y + offsetY + CGFloat(index) * (iconSize.height + spacing)
            )

            let iconSkeleton = SingleSkeleton.createRow(
                on: containerView,
                containerView: containerView,
                spaceSize: spaceSize,
                offset: iconOffset,
                size: iconSize
            )

            let titleOffset = CGPoint(
                x: iconOffset.x + iconSize.width + 18,
                y: iconOffset.y + 7
            )

            let titleSkeleton = SingleSkeleton.createRow(
                on: containerView,
                containerView: containerView,
                spaceSize: spaceSize,
                offset: titleOffset,
                size: titleSize
            )

            let subtitleOffset = CGPoint(
                x: titleOffset.x,
                y: titleOffset.y + titleSize.height + 15
            )

            let subtitleSkeleton = SingleSkeleton.createRow(
                on: containerView,
                containerView: containerView,
                spaceSize: spaceSize,
                offset: subtitleOffset,
                size: subtitleSize
            )

            return [iconSkeleton, titleSkeleton, subtitleSkeleton]
        }

        return [
            headerFirstLineSkeleton,
            headerSecondLineSkeleton,
            headerThirdLineSkeleton
        ] + compoundSkeletons.flatMap { $0 }
    }
}

extension StartStakingInfoViewLayout {
    enum Constants {
        static let footerHeight: CGFloat = 144
        static let footerContentSpace: CGFloat = 28
        static let footerSpacing: CGFloat = 12
        static let footerInsets = UIEdgeInsets(top: 16, left: 16, bottom: 31, right: 16)
        static let containerInsets = UIEdgeInsets(
            top: 12,
            left: 16,
            bottom: footerHeight,
            right: 16
        )
        static let containerSpacing: CGFloat = 32
        static let wikiAndTermsSpacing: CGFloat = 16
        static let actionViewHeight: CGFloat = UIConstants.actionHeight
        static let footerBorderWidth: CGFloat = 1
        static let linkChevronSize: CGFloat = 20.0
    }
}
