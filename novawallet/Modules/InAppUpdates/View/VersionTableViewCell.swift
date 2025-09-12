import UIKit

final class VersionTableViewCell: UITableViewCell {
    let titleLabel = UILabel(style: .secondaryScreenTitle, numberOfLines: 1)
    let severityLabel: BorderedLabelView = .create {
        $0.setContentHuggingPriority(.defaultLow, for: .vertical)
        $0.contentInsets = .init(top: 2, left: 6, bottom: 2, right: 6)
        $0.backgroundView.cornerRadius = 5
        $0.isHidden = true
    }

    let latestLabel: BorderedLabelView = .create {
        $0.apply(style: .latest)
        $0.contentInsets = .init(top: 2, left: 6, bottom: 2, right: 6)
        $0.backgroundView.cornerRadius = 5
        $0.setContentHuggingPriority(.defaultLow, for: .vertical)
        $0.isHidden = true
    }

    let dateLabel = UILabel(style: .caption1Secondary, numberOfLines: 1)
    let changelogView = MarkdownViewContainer(
        preferredWidth: UIScreen.main.bounds.width - 2 * UIConstants.horizontalInset
    )
    let separatorView: UIView = .createSeparator()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        let titleView = UIView.hStack(alignment: .center, spacing: 8, [
            titleLabel,
            severityLabel,
            latestLabel,
            UIView()
        ])

        contentView.addSubview(titleView)
        contentView.addSubview(dateLabel)
        contentView.addSubview(changelogView)
        contentView.addSubview(separatorView)

        titleView.snp.makeConstraints {
            $0.top.equalToSuperview().inset(16)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(28)
        }
        dateLabel.snp.makeConstraints {
            $0.top.equalTo(titleView.snp.bottom).offset(4)
            $0.leading.trailing.equalToSuperview()
        }
        changelogView.snp.makeConstraints {
            $0.top.equalTo(dateLabel.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview().inset(16)
        }
        separatorView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }
        changelogView.setContentHuggingPriority(.defaultLow, for: .vertical)
        changelogView.setContentCompressionResistancePriority(.required, for: .vertical)
    }
}

extension VersionTableViewCell {
    struct Model: Hashable {
        static func == (lhs: VersionTableViewCell.Model, rhs: VersionTableViewCell.Model) -> Bool {
            lhs.title == rhs.title &&
                lhs.isLatest == rhs.isLatest &&
                lhs.severity == rhs.severity &&
                lhs.date == rhs.date &&
                lhs.markdownText == rhs.markdownText
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(title)
        }

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
        latestLabel.titleLabel.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.inAppUpdatesLatest().uppercased()
        dateLabel.text = model.date
        bind(markdown: model.markdownText)
    }

    func bind(severity: ReleaseSeverity, locale: Locale) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable.self
        switch severity {
        case .normal:
            severityLabel.isHidden = true
        case .major:
            severityLabel.isHidden = false
            severityLabel.apply(style: .major)
            let title = strings.inAppUpdatesSeverityMajor()
            severityLabel.titleLabel.text = title.uppercased()
        case .critical:
            severityLabel.isHidden = false
            severityLabel.apply(style: .critical)
            let title = strings.inAppUpdatesSeverityCritical()
            severityLabel.titleLabel.text = title.uppercased()
        }
    }

    func bind(markdown: String) {
        changelogView.load(from: markdown) { [weak self] model in
            if model != nil {
                self?.invalidateIntrinsicContentSize()
                self?.setNeedsDisplay()
                self?.setNeedsLayout()
            }
        }
    }
}
