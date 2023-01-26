import UIKit

final class VersionTableViewCell: UITableViewCell {
    let titleLabel = UILabel(style: .secondaryScreenTitle, numberOfLines: 1)
    let severityLabel: BorderedLabelView = .create {
        $0.setContentHuggingPriority(.defaultLow, for: .vertical)
        $0.isHidden = true
    }

    let latestLabel: BorderedLabelView = .create {
        $0.apply(style: .latest)
        $0.setContentHuggingPriority(.defaultLow, for: .vertical)
        $0.isHidden = true
    }

    let dateLabel = UILabel(style: .caption1Secondary, numberOfLines: 1)
    let changelogView = MarkdownViewContainer(
        preferredWidth: UIScreen.main.bounds.width - 2 * UIConstants.horizontalInset
    )

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        let titleView = UIView.hStack(spacing: 8, [
            titleLabel,
            severityLabel,
            latestLabel,
            UIView()
        ])

        contentView.addSubview(titleView)
        contentView.addSubview(dateLabel)
        contentView.addSubview(changelogView)

        titleView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(16)
            $0.height.equalTo(28)
        }
        dateLabel.snp.makeConstraints {
            $0.top.equalTo(titleView.snp.bottom).offset(4)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        changelogView.snp.makeConstraints {
            $0.top.equalTo(dateLabel.snp.bottom).offset(12)
            $0.leading.trailing.bottom.equalToSuperview().inset(16)
        }
        changelogView.setContentHuggingPriority(.defaultLow, for: .vertical)
        changelogView.setContentCompressionResistancePriority(.required, for: .vertical)
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
        latestLabel.titleLabel.text = "latest".uppercased()
        dateLabel.text = model.date
        changelogView.load(from: model.markdownText) { [weak self] model in
            if model != nil {
                self?.setNeedsLayout()
                self?.layoutIfNeeded()
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
