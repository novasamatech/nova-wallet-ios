import UIKit
import SnapKit
import UIKit_iOS

final class AnalyticsPrivacyViewLayout: UIView {
    let containerView = ScrollableContainerView(axis: .vertical)

    let settingsRow: RoundedView = .create { view in
        view.fillColor = R.color.colorBlockBackground()!
        view.cornerRadius = Constants.cornerRadius
        view.shadowOpacity = 0
    }

    let iconImageView: UIImageView = .create { view in
        view.image = R.image.iconAnalyticsPrivacyShield()
        view.contentMode = .scaleAspectFit
    }

    let titleLabel: UILabel = .create { view in
        view.apply(style: .regularSubhedlinePrimary)
        view.numberOfLines = 0
    }

    let consentSwitch: UISwitch = .create { view in
        view.tintColor = R.color.colorSwitchBackground()
        view.onTintColor = R.color.colorIndicatorActive()
        view.thumbTintColor = R.color.colorIconPrimary()
        view.setContentCompressionResistancePriority(.required, for: .horizontal)

        let intrinsicSize = view.intrinsicContentSize
        view.transform = CGAffineTransform(
            scaleX: Constants.switchSize.width / intrinsicSize.width,
            y: Constants.switchSize.height / intrinsicSize.height
        )
    }

    let detailsView = AnalyticsConsentDetailsView(style: .compact)

    private let switchContainer = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(isOn: Bool, canToggle: Bool) {
        consentSwitch.setOn(isOn, animated: false)
        consentSwitch.isEnabled = canToggle
    }
}

private extension AnalyticsPrivacyViewLayout {
    func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        containerView.stackView.isLayoutMarginsRelativeArrangement = true
        containerView.stackView.layoutMargins = UIEdgeInsets(
            top: Constants.topInset,
            left: 0,
            bottom: Constants.horizontalInset,
            right: 0
        )
        containerView.stackView.spacing = Constants.sectionSpacing
        containerView.stackView.addArrangedSubview(settingsRow)
        containerView.stackView.addArrangedSubview(detailsView)

        settingsRow.snp.makeConstraints { make in
            make.height.equalTo(Constants.rowHeight)
        }

        [settingsRow, detailsView].forEach { view in
            view.snp.makeConstraints { make in
                make.width.equalToSuperview().offset(-2 * Constants.horizontalInset)
            }
        }

        switchContainer.addSubview(consentSwitch)
        consentSwitch.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        switchContainer.snp.makeConstraints { make in
            make.size.equalTo(Constants.switchSize)
        }

        let rowContent = UIView.hStack(alignment: .center, spacing: Constants.rowSpacing, [
            iconImageView, titleLabel, switchContainer
        ])
        settingsRow.addSubview(rowContent)
        rowContent.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.centerY.equalToSuperview()
        }
        iconImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }
    }

    enum Constants {
        static let cornerRadius: CGFloat = 12
        static let horizontalInset: CGFloat = 16
        static let topInset: CGFloat = 8
        static let sectionSpacing: CGFloat = 12
        static let rowSpacing: CGFloat = 12
        static let rowHeight: CGFloat = 48
        static let iconSize: CGFloat = 24
        static let switchSize = CGSize(width: 38, height: 22)
    }
}
