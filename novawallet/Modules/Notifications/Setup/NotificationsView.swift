import SoraUI
import SnapKit

final class NotificationsView: UIView {
    var contentView: NotificationView {
        topNotificationView
    }

    let topNotificationView = NotificationView()
    let middleNotificationView: NotificationView = .create {
        $0.contentView.isHidden = true
    }

    let bottomNotificationView: NotificationView = .create {
        $0.contentView.isHidden = true
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(topNotificationView)
        topNotificationView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
        }

        insertSubview(middleNotificationView, belowSubview: topNotificationView)
        insertSubview(bottomNotificationView, belowSubview: middleNotificationView)

        middleNotificationView.snp.makeConstraints { make in
            make.bottom.equalTo(topNotificationView).offset(20)
            make.centerX.equalTo(topNotificationView)
            make.size.equalTo(topNotificationView).multipliedBy(0.9)
        }

        bottomNotificationView.snp.makeConstraints { make in
            make.bottom.equalTo(middleNotificationView).offset(20)
            make.centerX.equalTo(middleNotificationView)
            make.size.equalTo(middleNotificationView).multipliedBy(0.9)
        }
    }
}

final class NotificationView: UIView {
    let backgroundView: RoundedView = .create {
        $0.fillColor = UIColor(red: 153 / 255, green: 158 / 255, blue: 199 / 255, alpha: 0.16)
        $0.cornerRadius = 18
        $0.shadowOpacity = 0.6
        $0.shadowRadius = 10
    }

    let iconView: UIImageView = .create {
        $0.image = R.image.iconNova()
        $0.setContentHuggingPriority(.low, for: .vertical)
        $0.setContentHuggingPriority(.required, for: .horizontal)
    }

    let titleView: UILabel = .create {
        $0.apply(style: .init(
            textColor: R.color.colorTextPrimary(),
            font: .systemFont(ofSize: 15)
        ))
    }

    let subtitleView: UILabel = .create {
        $0.apply(style: .init(
            textColor: R.color.colorTextSecondary(),
            font: .systemFont(ofSize: 12)
        ))
        $0.numberOfLines = 0
    }

    let accessoryView: UILabel = .create {
        $0.apply(style: .init(
            textColor: R.color.colorIconPrimary(),
            font: .systemFont(ofSize: 12)
        ))
        $0.setContentHuggingPriority(.low, for: .horizontal)
    }

    lazy var contentView = UIView.hStack(
        alignment: .center,
        spacing: 10,
        [
            iconView,
            UIView.hStack(alignment: .top, [
                UIView.vStack([
                    titleView,
                    subtitleView
                ]),
                accessoryView
            ])
        ]
    )

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        .init(width: UIView.noIntrinsicMetric, height: 73)
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(12)
            make.leading.equalToSuperview().offset(14)
            make.trailing.equalToSuperview().inset(18)
        }
    }
}
