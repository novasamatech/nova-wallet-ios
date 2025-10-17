import UIKit
import Foundation_iOS

final class NotificationsSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = NotificationsSetupViewLayout

    let presenter: NotificationsSetupPresenterProtocol

    init(
        presenter: NotificationsSetupPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NotificationsSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        presenter.setup()
    }

    private func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.self
        rootView.titleLabel.text = strings.notificationsSetupTitle()
        rootView.subtitleLabel.text = strings.notificationsSetupSubtitle()
        rootView.enableButton.imageWithTitleView?.title = strings.notificationsSetupEnablePushNotifications()
        rootView.notNowButton.imageWithTitleView?.title = strings.commonNotNow()
        rootView.notifications.contentView.titleView.text = strings.notificationsSetupNotificationTitle()
        rootView.notifications.contentView.subtitleView.text = strings.notificationsSetupNotificationSubtitle()
        rootView.notifications.contentView.accessoryView.text = strings.notificationsSetupNotificationAccessory()

        let marker = AttributedReplacementStringDecorator.marker
        let termsText = strings.notificationsSetupTerms(
            marker,
            marker
        )

        let attributedText = NSAttributedString(string: termsText)

        let termDecorator = CompoundAttributedStringDecorator.legal(for: selectedLocale, marker: marker)
        rootView.termsLabel.attributedText = termDecorator.decorate(attributedString: attributedText)
    }

    private func setupHandlers() {
        rootView.enableButton.addTarget(self, action: #selector(actionEnablePushNotifications), for: .touchUpInside)
        rootView.notNowButton.addTarget(self, action: #selector(actionNotNow), for: .touchUpInside)
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(actionTerms(gestureRecognizer:)))
        rootView.termsLabel.addGestureRecognizer(tapRecognizer)
    }

    @objc private func actionEnablePushNotifications() {
        presenter.enablePushNotifications()
    }

    @objc private func actionNotNow() {
        presenter.skip()
    }

    @objc private func actionTerms(gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            let location = gestureRecognizer.location(in: rootView.termsLabel.superview)

            if location.x < rootView.termsLabel.center.x {
                presenter.activateTerms()
            } else {
                presenter.activatePrivacy()
            }
        }
    }
}

extension NotificationsSetupViewController: NotificationsSetupViewProtocol {
    func didStartEnabling() {
        rootView.enableActionView.startLoading()

        rootView.notNowButton.isEnabled = false
        rootView.notNowButton.applyDisabledStyle()
    }

    func didStopEnabling() {
        rootView.enableActionView.stopLoading()

        rootView.notNowButton.isEnabled = true
        rootView.notNowButton.applySecondaryEnabledStyle()
    }
}

extension NotificationsSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
