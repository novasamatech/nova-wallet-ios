import UIKit

final class SubtensorSubnetParametersView: UIView {
    let splitView = SubtensorSubnetPoolSplitView()
    let stackView = UIStackView()
    private var rowViews: [SubtensorParameterRowView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlockBackground()
        layer.cornerRadius = 12
        stackView.axis = .vertical
        stackView.addArrangedSubview(splitView)
        addSubview(stackView)
        stackView.snp
            .makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 16, bottom: 12, right: 16))
            }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ model: SubtensorSubnetParametersViewModel) {
        splitView.bind(model)
        while rowViews.count < model.rows.count {
            let row = SubtensorParameterRowView(style: .parameter)
            rowViews.append(row)
            stackView.addArrangedSubview(row)
        }
        for (index, row) in rowViews.enumerated() {
            row.isHidden = index >= model.rows.count
            if index < model.rows.count { row.bind(model.rows[index]) }
        }
    }
}

final class SubtensorParameterRowView: UIView {
    struct Style {
        let title: UILabel.Style
        let titleLineHeight: CGFloat
        let value: UILabel.Style
        let valuesTopInset: CGFloat
        let verticalInset: CGFloat
        let minHeight: CGFloat

        static let parameter = Style(
            title: .regularSubhedlinePrimary,
            titleLineHeight: 20,
            value: .semiboldFootnotePrimary,
            valuesTopInset: 1,
            verticalInset: 10,
            minHeight: 0
        )

        static let detail = Style(
            title: .footnoteSecondary,
            titleLineHeight: 18,
            value: .footnotePrimary,
            valuesTopInset: 0,
            verticalInset: 5,
            minHeight: 44
        )
    }

    enum Constants {
        static let valueLineHeight: CGFloat = 18
        static let detailLineHeight: CGFloat = 16
    }

    let style: Style
    let titleLabel = UILabel()
    let valueLabel: UILabel = .create { $0.textAlignment = .right }
    let detailLabel: UILabel = .create { $0.apply(style: .caption1Secondary); $0.textAlignment = .right }
    let dividerView: UIView = .create { $0.backgroundColor = R.color.colorDivider() }
    let loadingView = SubtensorSkeletonView(cornerRadius: 6)
    private let tapRecognizer = UITapGestureRecognizer()

    var onTap: (() -> Void)? {
        didSet { tapRecognizer.isEnabled = onTap != nil }
    }

    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        titleLabel.apply(style: style.title)
        valueLabel.apply(style: style.value)
        tapRecognizer.addTarget(self, action: #selector(actionTap))
        tapRecognizer.isEnabled = false
        addGestureRecognizer(tapRecognizer)
        let values = UIView.vStack(
            alignment: .trailing,
            margins: UIEdgeInsets(top: style.valuesTopInset, left: 0, bottom: 0, right: 0),
            [valueLabel, detailLabel]
        )
        let content = UIView.hStack(alignment: .center, spacing: 12, [titleLabel, UIView(), values])
        addSubview(dividerView)
        addSubview(content)
        addSubview(loadingView)
        dividerView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(SubtensorDividerStyle.thickness)
        }
        content.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.bottom.equalToSuperview().inset(style.verticalInset)
        }
        loadingView.snp
            .makeConstraints { $0.trailing.centerY.equalToSuperview(); $0.width.equalTo(64); $0.height.equalTo(12) }
        snp.makeConstraints { $0.height.greaterThanOrEqualTo(style.minHeight) }
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        values.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ model: SubtensorParameterRowViewModel) {
        titleLabel.apply(text: model.title, lineHeight: style.titleLineHeight)
        valueLabel.apply(style: model.link != nil ? .footnoteAccentText : style.value)
        valueLabel.accessibilityTraits = model.link != nil ? .link : .staticText
        valueLabel.apply(text: model.value ?? "", lineHeight: Constants.valueLineHeight)
        detailLabel.apply(text: model.detail ?? "", lineHeight: Constants.detailLineHeight)
        detailLabel.isHidden = model.detail == nil
        loadingView.setLoading(model.value == nil)
    }

    @objc private func actionTap() {
        onTap?()
    }
}
