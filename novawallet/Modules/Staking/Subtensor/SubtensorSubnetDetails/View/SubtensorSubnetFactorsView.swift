import UIKit

final class SubtensorSubnetFactorsView: UIView {
    let tableView: StackTableView = .create { view in
        view.cellHeight = 60
        view.fillColor = .clear
    }

    let rows: [SubtensorSubnetFactorRowView] = SubtensorSubnetFactor.Kind.allCases.map { _ in
        SubtensorSubnetFactorRowView()
    }

    let footerLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
        label.numberOfLines = 0
    }

    let reasonsLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
        label.numberOfLines = 0
    }

    let freshnessLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
        label.numberOfLines = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlockBackground()
        layer.cornerRadius = 12

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorSubnetFactorsViewModel) {
        zip(rows, viewModel.rows).forEach { row, rowViewModel in
            row.bind(viewModel: rowViewModel)
        }

        bind(text: viewModel.footer, to: footerLabel)
        bind(text: viewModel.reasons, to: reasonsLabel)
        bind(text: viewModel.freshness, to: freshnessLabel)
    }
}

private extension SubtensorSubnetFactorsView {
    func bind(text: String?, to label: UILabel) {
        label.text = text
        label.isHidden = text == nil
    }

    func setupLayout() {
        rows.forEach { tableView.addArrangedSubview($0) }
        tableView.setShowsSeparator(false, at: rows.count - 1)

        let footerView = UIView.vStack(
            spacing: 4,
            margins: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16),
            [footerLabel, reasonsLabel, freshnessLabel]
        )

        let contentView = UIView.vStack(spacing: 4, [tableView, footerView])

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(4)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(16)
        }
    }
}
