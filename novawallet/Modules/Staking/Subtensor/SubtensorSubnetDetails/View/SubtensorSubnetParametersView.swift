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
            .makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 16, left: 16, bottom: 4, right: 16))
            }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ model: SubtensorSubnetParametersViewModel) {
        splitView.bind(model)
        while rowViews.count < model.rows.count {
            let row = SubtensorParameterRowView()
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
    let titleLabel: UILabel = .create { $0.apply(style: .footnoteSecondary) }
    let valueLabel: UILabel = .create { $0.apply(style: .footnotePrimary); $0.textAlignment = .right }
    let detailLabel: UILabel = .create { $0.apply(style: .caption1Secondary); $0.textAlignment = .right }
    let dividerView: UIView = .create { $0.backgroundColor = R.color.colorDivider() }
    let loadingView = SubtensorChartLoadingView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let values = UIView.vStack(alignment: .trailing, spacing: 2, [valueLabel, detailLabel])
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
            $0.top.bottom.equalToSuperview().inset(10)
        }
        loadingView.snp
            .makeConstraints { $0.trailing.centerY.equalToSuperview(); $0.width.equalTo(64); $0.height.equalTo(10) }
        snp.makeConstraints { $0.height.greaterThanOrEqualTo(44) }
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        values.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ model: SubtensorParameterRowViewModel) {
        titleLabel.text = model.title
        valueLabel.text = model.value
        detailLabel.text = model.detail
        detailLabel.isHidden = model.detail == nil
        loadingView.setLoading(model.value == nil)
    }
}
