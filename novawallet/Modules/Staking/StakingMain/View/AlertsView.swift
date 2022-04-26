import UIKit
import SoraUI

protocol AlertsViewDelegate: AnyObject {
    func didSelectStakingAlert(_ alert: StakingAlert)
}

final class AlertsView: UIView {
    weak var delegate: AlertsViewDelegate?

    private let backgroundView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        view.sideLength = 12
        return view
    }()

    private let titleView: IconDetailsView = {
        let view = IconDetailsView()
        view.mode = .iconDetails
        view.spacing = 8.0
        view.iconWidth = 16.0

        view.detailsLabel.numberOfLines = 1
        view.detailsLabel.font = .regularSubheadline
        view.detailsLabel.textColor = R.color.colorYellow()

        let icon = R.image.iconWarning()?.tinted(with: R.color.colorYellow()!)
        view.imageView.image = icon

        return view
    }()

    private let alertsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
                applyAlerts()
            }
        }
    }

    private var alerts: [StakingAlert]?

    override init(frame: CGRect) {
        super.init(frame: frame)

        applyLocalization()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        titleView.detailsLabel.text = R.string.localizable.stakingAlertsTitle(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16.0)
            make.leading.equalToSuperview().inset(16.0)
        }

        addSubview(alertsStackView)
        alertsStackView.snp.makeConstraints { make in
            make.top.equalTo(titleView.snp.bottom).offset(3.0)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(13.0)
        }
    }

    func bind(alerts: [StakingAlert]) {
        self.alerts = alerts
        applyAlerts()
    }

    private func applyAlerts() {
        guard let alerts = alerts else {
            return
        }

        alertsStackView.subviews.forEach { $0.removeFromSuperview() }
        if alerts.isEmpty {
            alertsStackView.isHidden = true
        } else {
            alertsStackView.isHidden = false

            var itemViews = [UIView]()
            for alert in alerts {
                let alertView = AlertItemView(stakingAlert: alert, locale: locale)
                let rowView = RowView(contentView: alertView)
                rowView.borderView.strokeColor = R.color.colorBlurSeparator()!
                rowView.borderView.borderType = .none

                rowView.contentInsets = UIEdgeInsets(
                    top: 0.0,
                    left: UIConstants.horizontalInset,
                    bottom: 0.0,
                    right: UIConstants.horizontalInset
                )

                rowView.addTarget(self, action: #selector(handleSelectItem), for: .touchUpInside)
                itemViews.append(rowView)
            }

            itemViews.forEach { alertsStackView.addArrangedSubview($0) }
        }
    }

    @objc
    private func handleSelectItem(sender: UIControl) {
        guard let rowView = sender as? RowView<AlertItemView> else { return }
        delegate?.didSelectStakingAlert(rowView.rowContentView.alertType)
    }
}

private class AlertItemView: UIView {
    let alertType: StakingAlert

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTransparentText()
        label.numberOfLines = 0
        return label
    }()

    let accessoryView: UIView = {
        let view = UIImageView()
        view.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorWhite48()!)
        return view
    }()

    init(stakingAlert: StakingAlert, locale: Locale) {
        alertType = stakingAlert

        super.init(frame: .zero)

        setupLayout()

        titleLabel.text = stakingAlert.title(for: locale)
        descriptionLabel.text = stakingAlert.description(for: locale)
        accessoryView.isHidden = !stakingAlert.hasAssociatedAction
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(accessoryView)
        accessoryView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview()
            make.size.equalTo(24)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(13)
            make.leading.equalToSuperview()
            make.trailing.lessThanOrEqualTo(accessoryView.snp.leading).offset(-UIConstants.horizontalInset)
        }

        addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalTo(titleLabel.snp.leading)
            make.bottom.equalToSuperview().inset(8)
            make.trailing.lessThanOrEqualTo(accessoryView.snp.leading).offset(-UIConstants.horizontalInset)
        }
    }
}
