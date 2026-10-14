import UIKit

final class SubtensorWhereToStakeViewLayout: UIView {
    let container = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
    let carousel = UIScrollView()
    let cardsStack = UIStackView()
    let pageControl = ExtendedPageControl()
    let previousButton = UIButton(type: .system)
    let nextButton = UIButton(type: .system)
    let captionLabel = UILabel(style: .caption1Secondary, textAlignment: .center, numberOfLines: 0)
    private(set) var cards: [SubtensorWhereToStakeCardView] = []

    var stride: CGFloat { max(carousel.bounds.width - 72, 1) + 12 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(cards models: [SubtensorWhereToStakeCardModel], onChoose: @escaping (SubtensorQuickPickOrder) -> Void) {
        cards.forEach { $0.removeFromSuperview() }
        cards = models.map { model in
            let card = SubtensorWhereToStakeCardView(model: model)
            card.chooseButton.addAction(UIAction { _ in onChoose(model.order) }, for: .touchUpInside)
            cardsStack.addArrangedSubview(card)
            card.snp.makeConstraints { $0.width.equalTo(carousel.frameLayoutGuide).offset(-72) }
            return card
        }
        pageControl.numberOfPages = cards.count
    }
}

private extension SubtensorWhereToStakeViewLayout {
    func setupLayout() {
        addSubview(container)
        container.snp.makeConstraints { $0.edges.equalToSuperview() }
        container.stackView.alignment = .fill
        container.stackView.spacing = 16
        container.stackView.addArrangedSubview(carousel)
        carousel.showsHorizontalScrollIndicator = false
        carousel.decelerationRate = .fast
        carousel.snp.makeConstraints { $0.height.equalTo(548).priority(.high); $0.height.greaterThanOrEqualTo(548) }
        cardsStack.axis = .horizontal
        cardsStack.spacing = 12
        carousel.addSubview(cardsStack)
        cardsStack.snp.makeConstraints { make in
            make.leading.equalTo(carousel.contentLayoutGuide).offset(16)
            make.trailing.equalTo(carousel.contentLayoutGuide).offset(-56)
            make.top.bottom.equalTo(carousel.contentLayoutGuide)
            make.height.equalTo(carousel.frameLayoutGuide)
        }
        container.stackView.addArrangedSubview(captionLabel)
        let controls = UIView()
        container.stackView.addArrangedSubview(controls)
        controls.snp.makeConstraints { $0.height.equalTo(72) }
        [previousButton, pageControl, nextButton].forEach(controls.addSubview)
        previousButton.setImage(R.image.iconSmallArrow()?.withHorizontallyFlippedOrientation(), for: .normal)
        nextButton.setImage(R.image.iconSmallArrow(), for: .normal)
        previousButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16); make.centerY.equalToSuperview(); make.size.equalTo(40)
        }
        nextButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16); make.centerY.equalToSuperview(); make.size.equalTo(40)
        }
        pageControl.snp.makeConstraints { $0.center.equalToSuperview() }
        [previousButton, nextButton].forEach {
            $0.backgroundColor = R.color.colorBlockBackground()
            $0.layer.cornerRadius = 20
        }
    }
}
