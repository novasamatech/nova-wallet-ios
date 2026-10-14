import UIKit

final class SubtensorWhereToStakeCardView: UIView {
    let chooseButton: TriangularedButton = .create { $0.applyDefaultStyle() }
    private let gradient = CAGradientLayer()

    init(model: SubtensorWhereToStakeCardModel) {
        super.init(frame: .zero)
        layer.cornerRadius = 20
        layer.borderWidth = 1
        layer.borderColor = model.tint.cgColor
        clipsToBounds = true
        gradient.colors = [model.tint.withAlphaComponent(0.45).cgColor, R.color.colorBlockBackground()!.cgColor]
        layer.insertSublayer(gradient, at: 0)
        setupLayout(model: model)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}

private extension SubtensorWhereToStakeCardView {
    func label(_ text: String, style: UILabel.Style) -> UILabel {
        let label = UILabel()
        label.apply(style: style)
        label.text = text
        label.numberOfLines = 0
        return label
    }

    func setupLayout(model: SubtensorWhereToStakeCardModel) {
        let artwork = UIImageView(image: model.artwork)
        artwork.contentMode = .scaleAspectFit
        addSubview(artwork)
        artwork.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(156)
        }
        let title = label(model.title, style: .boldTitle2Primary)
        let subtitle = label(model.subtitle, style: .footnoteSecondary)
        let headings = UIView.vStack(spacing: 2, [title, subtitle])
        addSubview(headings)
        headings.snp.makeConstraints { make in
            make.top.equalTo(artwork.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        let copy = UIView.vStack(spacing: 6, [])
        copy.addArrangedSubview(label(model.prosTitle, style: .caption2Secondary))
        model.pros.forEach { copy.addArrangedSubview(label("+  \($0)", style: .caption1Primary)) }
        if !model.cons.isEmpty {
            let cons = label(model.consTitle, style: .caption2Secondary)
            copy.addArrangedSubview(cons)
            model.cons.forEach { copy.addArrangedSubview(label("−  \($0)", style: .caption1Primary)) }
        }
        if let unavailable = model.unavailable {
            copy.addArrangedSubview(label(unavailable, style: .caption1Secondary))
        }
        addSubview(copy)
        copy.snp.makeConstraints { make in
            make.top.equalTo(headings.snp.bottom).offset(54)
            make.leading.trailing.equalToSuperview().inset(22)
        }
        addSubview(chooseButton)
        chooseButton.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(copy.snp.bottom).offset(20)
            make.leading.trailing.bottom.equalToSuperview().inset(20)
            make.height.equalTo(52)
        }
        chooseButton.imageWithTitleView?.title = model.chooseTitle
        chooseButton.isUserInteractionEnabled = model.unavailable == nil
        if model.unavailable != nil { chooseButton.applyDisabledStyle() }
        chooseButton.invalidateLayout()
    }
}
