import UIKit

final class VersionTableViewCell: UITableViewCell {
    let titleLabel = UILabel(style: .secondaryScreenTitle, numberOfLines: 1)
    let severityLabel: BorderedLabelView = .create {
        $0.isHidden = true
    }

    let latestLabel: BorderedLabelView = .create {
        $0.apply(style: .latest)
        $0.isHidden = true
    }

    let dateLabel = UILabel(style: .caption1Secondary, numberOfLines: 1)
    let changelogView = MarkdownViewContainer(
        preferredWidth: UIScreen.main.bounds.width - 2 * UIConstants.horizontalInset
    )

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        let content = UIView.vStack(spacing: 4, [
            .hStack([
                titleLabel,
                severityLabel,
                latestLabel,
                UIView()
            ]),
            dateLabel,
            changelogView
        ])

        content.setCustomSpacing(12, after: dateLabel)
        contentView.addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

extension VersionTableViewCell {
    struct Model: Hashable {
        let title: String
        let isLatest: Bool
        let severity: ReleaseSeverity
        let date: String
        let markdownText: String
    }

    func bind(model: Model, locale: Locale) {
        titleLabel.text = model.title
        bind(severity: model.severity, locale: locale)
        latestLabel.isHidden = !model.isLatest
        dateLabel.text = model.date
        changelogView.load(from: model.markdownText) { [weak self] model in
            if model != nil {
                // self?.activityIndicator.stopAnimating()
            }
        }
    }

    func bind(severity: ReleaseSeverity, locale _: Locale) {
        switch severity {
        case .normal:
            severityLabel.isHidden = true
        case .major:
            severityLabel.isHidden = false
            severityLabel.apply(style: .major)
            severityLabel.titleLabel.text = "major".uppercased()
        case .critical:
            severityLabel.isHidden = false
            severityLabel.apply(style: .critical)
            severityLabel.titleLabel.text = "critical".uppercased()
        }
    }
}
