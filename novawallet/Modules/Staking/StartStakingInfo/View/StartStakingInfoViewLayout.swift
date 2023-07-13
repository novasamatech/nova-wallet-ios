import UIKit
import SoraUI

final class StartStakingInfoViewLayout: ScrollableContainerLayoutView {
    var style: MultiColorTextStyle = .defaultStyle
    var skeletonView: SkrullableView?

    var header: StackTableHeaderCell = .create {
        $0.titleLabel.textAlignment = .center
    }

    lazy var wikiView: UITextView = .create {
        $0.textAlignment = .center
        $0.linkTextAttributes = [.foregroundColor: R.color.colorTextSecondary()!,
                                 .font: UIFont.semiBoldCallout]
        $0.font = .regularCallout
        $0.textColor = R.color.colorTextTertiary()
        $0.isScrollEnabled = false
        $0.backgroundColor = .clear
        $0.isEditable = false
        $0.textContainerInset = .zero
    }

    lazy var termsView: UITextView = .create {
        $0.textAlignment = .center
        $0.linkTextAttributes = [.foregroundColor: R.color.colorTextSecondary()!,
                                 .font: UIFont.semiBoldCallout]
        $0.font = .regularCallout
        $0.textColor = R.color.colorTextTertiary()
        $0.isScrollEnabled = false
        $0.backgroundColor = .clear
        $0.isEditable = false
        $0.textContainerInset = .zero
    }

    let footer: RoundedView = .create { view in
        view.applyFilledBackgroundStyle()
        view.fillColor = R.color.colorBottomSheetBackground()!
        view.highlightedFillColor = R.color.colorBottomSheetBackground()!
        view.strokeColor = R.color.colorContainerBorder()!
        view.highlightedStrokeColor = R.color.colorContainerBorder()!
        view.strokeWidth = 1
        view.cornerRadius = 12
        view.roundingCorners = [.topLeft, .topRight]
    }

    lazy var actionView: LoadableActionView = .create {
        $0.actionButton.applyEnabledStyle(colored: self.style.accentTextColor)
    }

    let balanceLabel = UILabel(style: .regularSubhedlineSecondary, textAlignment: .center, numberOfLines: 1)
    var paragraphViews: [ParagraphView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
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
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(Constants.footerHeight)
        }
    }

    func updateContent(
        title: AccentTextModel,
        paragraphs: [ParagraphView.Model],
        wikiUrl: StartStakingUrlModel,
        termsUrl: StartStakingUrlModel
    ) {
        containerView.stackView.arrangedSubviews.forEach(containerView.stackView.removeArrangedSubview)
        containerView.stackView.spacing = Constants.containerSpacing

        set(title: title)
        set(paragraphs: paragraphs)
        setWiki(urlModel: wikiUrl)
        setTerms(urlModel: termsUrl)

        containerView.setNeedsLayout()
        layoutIfNeeded()
    }

    func updateBalanceButton(text: String, locale: Locale) {
        balanceLabel.text = text
        actionView.actionButton.imageWithTitleView?.title = R.string.localizable.stakingStartTitle(
            preferredLanguages: locale.rLanguages)
    }

    private func set(title: AccentTextModel) {
        header.titleLabel.bind(model: title, with: style)
        header.titleLabel.numberOfLines = 0
        containerView.stackView.addArrangedSubview(header)
    }

    private func set(paragraphs: [ParagraphView.Model]) {
        paragraphs.forEach {
            let view = ParagraphView(frame: .zero)
            view.style = style
            view.bind(viewModel: $0)
            view.contentInsets = .zero
            paragraphViews.append(view)
            containerView.stackView.addArrangedSubview(view)
        }
    }

    private func setWiki(urlModel model: StartStakingUrlModel) {
        wikiView.bind(url: model.url, urlText: model.urlName, in: model.text)
        addArrangedSubview(wikiView)
        stackView.setCustomSpacing(Constants.wikiAndTermsSpacing, after: wikiView)
    }

    private func setTerms(urlModel model: StartStakingUrlModel) {
        termsView.bind(url: model.url, urlText: model.urlName, in: model.text)
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

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let offsetX: CGFloat = 18
        let offsetY: CGFloat = 39
        let spacing: CGFloat = 41
        let iconSize = CGSize(width: 28, height: 28)
        let titleSize = CGSize(width: 155, height: 10)
        let subtitleSize = CGSize(width: 126, height: 10)

        let headerFirstLineSize = CGSize(width: 145, height: 16)
        let headerSecondLineSize = CGSize(width: 185, height: 16)
        let headerThirdLineSize = CGSize(width: 109, height: 16)

        let headerFirstLineOffset = CGPoint(
            x: spaceSize.width / 2 - headerFirstLineSize.width / 2,
            y: 71
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
                y: iconOffset.y + 8
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
            top: 0,
            left: 16,
            bottom: footerHeight,
            right: 16
        )
        static let containerSpacing: CGFloat = 32
        static let wikiAndTermsSpacing: CGFloat = 16
        static let actionViewHeight: CGFloat = UIConstants.actionHeight
    }
}
