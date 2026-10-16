import UIKit

final class SubtensorWhereToStakeCardView: UIView {
    override static var layerClass: AnyClass { CAGradientLayer.self }

    var onChoose: (() -> Void)?

    var focus: CGFloat = 1 {
        didSet { focusBorderView.alpha = focus }
    }

    private let chooseButton: TriangularedButton = .create { button in
        button.applyDefaultStyle()
        button.triangularedView?.sideLength = Constants.buttonRadius
    }

    private let artworkView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
        view.setContentCompressionResistancePriority(.defaultHigh - 1, for: .vertical)
    }

    private let titleLabel = UILabel(style: .boldTitle2Primary)
    private let subtitleLabel = UILabel(style: .footnoteSecondary)
    private let listsView = UIView.vStack(spacing: Constants.listSpacing, [])
    private let focusBorderView: UIView = .create { view in
        view.isUserInteractionEnabled = false
        view.layer.cornerRadius = Constants.cornerRadius
        view.layer.borderWidth = Constants.borderWidth
    }

    private var gradientLayer: CAGradientLayer? { layer as? CAGradientLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupAppearance()
        setupLayout()
        chooseButton.addAction(UIAction { [weak self] _ in self?.onChoose?() }, for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(model: SubtensorWhereToStakeCardModel) {
        gradientLayer?.colors = model.palette.gradient.map(\.cgColor)
        focusBorderView.layer.borderColor = model.palette.border.cgColor
        artworkView.image = model.artwork
        titleLabel.apply(text: model.title, lineHeight: Constants.titleLineHeight)
        subtitleLabel.apply(text: model.subtitle, lineHeight: Constants.subtitleLineHeight)
        bindLists(model: model)
        chooseButton.imageWithTitleView?.title = model.chooseTitle
        chooseButton.invalidateLayout()
    }
}

private extension SubtensorWhereToStakeCardView {
    func setupAppearance() {
        gradientLayer?.startPoint = Constants.gradientStart
        gradientLayer?.endPoint = Constants.gradientEnd
        gradientLayer?.locations = Constants.gradientLocations
        layer.cornerRadius = Constants.cornerRadius
        layer.borderWidth = Constants.borderWidth
        layer.borderColor = R.color.colorContainerBorder()?.cgColor
        layer.masksToBounds = true
    }

    func setupLayout() {
        [artworkView, titleLabel, subtitleLabel, listsView, chooseButton, focusBorderView].forEach(addSubview)
        focusBorderView.snp.makeConstraints { $0.edges.equalToSuperview() }
        artworkView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(artworkView.snp.bottom).offset(Constants.titleTopSpacing)
            make.leading.trailing.equalToSuperview().inset(Constants.textInset)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Constants.subtitleTopSpacing)
            make.leading.trailing.equalToSuperview().inset(Constants.textInset)
        }
        listsView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(Constants.listsTopSpacing).priority(.medium)
            make.top.greaterThanOrEqualTo(subtitleLabel.snp.bottom).offset(Constants.minimumSpacing)
            make.leading.trailing.equalToSuperview().inset(Constants.listsInset)
        }
        chooseButton.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(listsView.snp.bottom).offset(Constants.minimumSpacing)
            make.leading.trailing.bottom.equalToSuperview().inset(Constants.textInset)
            make.height.equalTo(Constants.buttonHeight)
        }
    }

    func bindLists(model: SubtensorWhereToStakeCardModel) {
        listsView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        listsView.addArrangedSubview(makeHeader(model.prosTitle))
        model.pros.forEach { listsView.addArrangedSubview(makeRow($0, sign: Constants.proSign, model: model)) }
        guard !model.cons.isEmpty, let lastPro = listsView.arrangedSubviews.last else { return }
        listsView.setCustomSpacing(Constants.groupSpacing, after: lastPro)
        listsView.addArrangedSubview(makeHeader(model.consTitle))
        model.cons.forEach { listsView.addArrangedSubview(makeRow($0, sign: Constants.conSign, model: model)) }
    }

    func makeHeader(_ text: String) -> UILabel {
        let label = UILabel(style: .semiboldCaps2Secondary)
        label.applySubtensorCaps(text)
        return label
    }

    func makeRow(_ text: String, sign: String, model: SubtensorWhereToStakeCardModel) -> UIView {
        let mark = UILabel(style: .semiboldCaption1Primary, textAlignment: .center, numberOfLines: 1)
        mark.text = sign
        mark.backgroundColor = model.palette.mark
        mark.layer.cornerRadius = Constants.markSize / 2
        mark.layer.masksToBounds = true
        mark.snp.makeConstraints { $0.size.equalTo(Constants.markSize) }
        let label = UILabel(style: .caption1Primary)
        label.apply(text: text, lineHeight: Constants.rowLineHeight)
        return UIView.hStack(alignment: .top, spacing: Constants.markSpacing, [mark, label])
    }
}

private extension SubtensorWhereToStakeCardView {
    enum Constants {
        static let cornerRadius: CGFloat = 20
        static let borderWidth: CGFloat = 1
        static let gradientStart = CGPoint(x: 0.061, y: -0.016)
        static let gradientEnd = CGPoint(x: 0.939, y: 1.016)
        static let gradientLocations: [NSNumber] = [0.0763, 0.5, 0.9237]
        static let titleTopSpacing: CGFloat = 6
        static let subtitleTopSpacing: CGFloat = 2
        static let listsTopSpacing: CGFloat = 60
        static let minimumSpacing: CGFloat = 16
        static let textInset: CGFloat = 20
        static let listsInset: CGFloat = 22
        static let listSpacing: CGFloat = 6
        static let groupSpacing: CGFloat = 16
        static let titleLineHeight: CGFloat = 28
        static let subtitleLineHeight: CGFloat = 18
        static let rowLineHeight: CGFloat = 16
        static let markSize: CGFloat = 16
        static let markSpacing: CGFloat = 8
        static let proSign = "+"
        static let conSign = "\u{2212}"
        static let buttonHeight: CGFloat = 52
        static let buttonRadius: CGFloat = 12
    }
}
