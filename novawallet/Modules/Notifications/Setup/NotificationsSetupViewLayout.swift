import UIKit
import UIKit_iOS

final class NotificationsSetupViewLayout: UIView {
    let titleImage: UIImageView = .create {
        $0.image = R.image.iconNotificationRing()
    }

    let titleLabel: UILabel = .create {
        $0.apply(style: .boldTitle3Primary)
        $0.textAlignment = .center
    }

    let subtitleLabel: UILabel = .create {
        $0.apply(style: .footnoteSecondary)
        $0.numberOfLines = 0
        $0.textAlignment = .center
    }

    let notifications = NotificationsView()

    var enableButton: TriangularedButton {
        enableActionView.actionButton
    }

    let enableActionView: LoadableActionView = .create {
        $0.actionButton.applyDefaultStyle()
        $0.actionLoadingView.applyPrimaryButtonEnabledStyle()
    }

    let notNowButton: TriangularedButton = .create {
        $0.applySecondaryDefaultStyle()
    }

    let termsLabel: UILabel = .create {
        $0.isUserInteractionEnabled = true
        $0.numberOfLines = 0
        $0.textAlignment = .center
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()!
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(titleImage)
        titleImage.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(64)
            make.height.width.equalTo(88)
        }
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleImage.snp.bottom).offset(16)
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(16)
        }
        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(16)
        }
        addSubview(notifications)
        notifications.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(40)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        addSubview(termsLabel)
        termsLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-8)
        }

        addSubview(notNowButton)
        notNowButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(termsLabel.snp.top).offset(-16)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(enableActionView)
        enableActionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(notNowButton.snp.top).offset(-16)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
