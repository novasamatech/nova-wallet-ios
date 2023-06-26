import UIKit

final class StartStakingInfoViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = Constants.containerInsets
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    var style: MultiColorTextStyle = .defaultStyle

    var header: StackTableHeaderCell = .create {
        $0.titleLabel.textAlignment = .center
    }

    lazy var wikiView: UITextView = .create {
        $0.textAlignment = .center
        $0.linkTextAttributes = [.foregroundColor: R.color.colorTextSecondary()!,
                                 .font: UIFont.semiBoldCallout]
        $0.font = .regularCallout
        $0.textColor = R.color.colorTextSecondary()
        $0.isScrollEnabled = false
        $0.backgroundColor = .clear
        $0.isEditable = false
    }

    lazy var termsView: UITextView = .create {
        $0.textAlignment = .center
        $0.linkTextAttributes = [.foregroundColor: R.color.colorTextSecondary()!,
                                 .font: UIFont.semiBoldCallout]
        $0.font = .regularCallout
        $0.textColor = R.color.colorTextSecondary()
        $0.isScrollEnabled = false
        $0.backgroundColor = .clear
        $0.isEditable = false
    }

    let footer: BlockBackgroundView = .create {
        $0.cornerCut = [.topLeft, .topRight]
    }

    let actionView = LoadableActionView()
    let balanceLabel = UILabel(style: .regularSubhedlineSecondary, textAlignment: .center, numberOfLines: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        let footerContentView = UIView.vStack(spacing: Constants.footerSpacing, [
            actionView,
            balanceLabel
        ])
        footer.addSubview(footerContentView)
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
    }

    func updateBalanceButton(text: String, locale: Locale) {
        balanceLabel.text = text
        actionView.actionButton.imageWithTitleView?.title = R.string.localizable.stakingStartTitle(
            preferredLanguages: locale.rLanguages)
    }

    private func set(title: AccentTextModel) {
        header.titleLabel.bind(model: title, with: style)
        containerView.stackView.addArrangedSubview(header)
    }

    private func set(paragraphs: [ParagraphView.Model]) {
        paragraphs.forEach {
            let view = ParagraphView(frame: .zero)
            view.style = style
            view.bind(viewModel: $0)
            containerView.stackView.addArrangedSubview(view)
        }
    }

    private func setWiki(urlModel model: StartStakingUrlModel) {
        wikiView.bind(url: model.url, urlText: model.urlName, in: model.text)
        containerView.stackView.addArrangedSubview(wikiView)
        containerView.stackView.setCustomSpacing(Constants.wikiAndTermsSpacing, after: wikiView)
    }

    private func setTerms(urlModel model: StartStakingUrlModel) {
        termsView.bind(url: model.url, urlText: model.urlName, in: model.text)
        containerView.stackView.addArrangedSubview(termsView)
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
            bottom: footerContentSpace + footerHeight,
            right: 16
        )
        static let containerSpacing: CGFloat = 32
        static let wikiAndTermsSpacing: CGFloat = 16
    }
}
