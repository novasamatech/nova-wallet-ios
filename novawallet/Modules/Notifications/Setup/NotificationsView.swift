import UIKit
import UIKit_iOS
import SnapKit

final class NotificationsView: UIView {
    var contentView: NotificationView {
        topNotificationView
    }

    let topNotificationView: NotificationView = .create {
        $0.backgroundView.fillColor = R.color.colorNotificationFirstLayerBackground()!
    }

    let middleNotificationView: NotificationView = .create {
        $0.contentView.isHidden = true
        $0.backgroundView.fillColor = R.color.colorNotificationSecondLayerBackground()!
    }

    let bottomNotificationView: NotificationView = .create {
        $0.contentView.isHidden = true
        $0.backgroundView.fillColor = R.color.colorNotificationThirdLayerBackground()!
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
            make.bottom.equalTo(topNotificationView).offset(16)
            make.centerX.equalTo(topNotificationView)
            make.size.equalTo(topNotificationView).multipliedBy(0.9)
        }

        bottomNotificationView.snp.makeConstraints { make in
            make.bottom.equalTo(middleNotificationView).offset(16)
            make.bottom.equalToSuperview()
            make.centerX.equalTo(middleNotificationView)
            make.size.equalTo(middleNotificationView).multipliedBy(0.9)
        }
    }
}

final class NotificationView: UIView {
    let backgroundView: RoundedView = .create {
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
            textColor: R.color.colorTextPrimary(),
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
            UIView.hStack(
                alignment: .top,
                [
                    UIView.vStack(spacing: 4, [
                        titleView,
                        subtitleView
                    ]),
                    accessoryView
                ]
            )
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
