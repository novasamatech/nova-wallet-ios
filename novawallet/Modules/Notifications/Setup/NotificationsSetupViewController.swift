import UIKit
import SoraFoundation

final class NotificationsSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = NotificationsSetupViewLayout

    let presenter: NotificationsSetupPresenterProtocol
    let termDecorator: LocalizableResource<AttributedStringDecoratorProtocol>

    init(
        presenter: NotificationsSetupPresenterProtocol,
        termDecorator: LocalizableResource<AttributedStringDecoratorProtocol>,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.termDecorator = termDecorator
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
        let strings = R.string.localizable.self
        rootView.titleLabel.text = strings.notificationsSetupTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.subtitleLabel.text = strings.notificationsSetupSubtitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.enableButton.imageWithTitleView?.title = strings.notificationsSetupEnablePushNotifications(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.notNowButton.imageWithTitleView?.title = strings.commonNotNow(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.notifications.contentView.titleView.text = strings.notificationsSetupNotificationTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.notifications.contentView.subtitleView.text = strings.notificationsSetupNotificationSubtitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.notifications.contentView.accessoryView.text = strings.notificationsSetupNotificationAccessory(
            preferredLanguages: selectedLocale.rLanguages
        )

        let termsText = strings.notificationsSetupTerms(
            preferredLanguages: selectedLocale.rLanguages
        )

        let attributedText = NSAttributedString(string: termsText)
        rootView.termsLabel.attributedText = termDecorator.value(
            for: selectedLocale
        ).decorate(attributedString: attributedText)
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

extension NotificationsSetupViewController: NotificationsSetupViewProtocol {}

extension NotificationsSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
