import UIKit
import Foundation_iOS
import UIKit_iOS

final class ConsentBannerUpgradeViewController: UIViewController, ViewHolder {
    typealias RootViewType = ConsentBannerUpgradeViewLayout

    let presenter: ConsentBannerUpgradePresenterProtocol

    init(
        presenter: ConsentBannerUpgradePresenterProtocol,
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
        view = ConsentBannerUpgradeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        applyConsentState()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string(preferredLanguages: languages).localizable.consentBannerUpgradeTitle()
        rootView.descriptionLabel.text = R.string(preferredLanguages: languages).localizable.consentBannerUpgradeDescription()
        rootView.acceptButton.imageWithTitleView?.title = R.string(preferredLanguages: languages).localizable.consentBannerUpgradeAccept()

        let marker = AttributedReplacementStringDecorator.marker
        let consentText = R.string(preferredLanguages: languages).localizable.consentBannerTextTemplate(
            marker,
            marker
        )

        let consentDecorator = CompoundAttributedStringDecorator.consentBanner(
            for: selectedLocale,
            marker: marker
        )
        let attributedText = NSAttributedString(string: consentText)
        rootView.consentLabel.attributedText = consentDecorator.decorate(attributedString: attributedText)
    }

    private func setupHandlers() {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(actionTerms(gestureRecognizer:)))
        rootView.consentLabel.addGestureRecognizer(tapRecognizer)

        rootView.consentCheckbox.addTarget(self, action: #selector(actionToggleConsent), for: .touchUpInside)
        rootView.acceptButton.addTarget(self, action: #selector(actionAccept), for: .touchUpInside)
    }

    private func applyConsentState() {
        let isAccepted = rootView.consentCheckbox.isSelected
        rootView.acceptButton.isEnabled = isAccepted
    }

    @objc private func actionToggleConsent() {
        rootView.consentCheckbox.isSelected.toggle()
        applyConsentState()
    }

    @objc private func actionAccept() {
        presenter.acceptConsent()
    }

    @objc private func actionTerms(gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .ended else { return }

        // Same y-axis line detection heuristic as the welcome screen — the
        // Aurum-mandated text wraps with "Terms of Service" on line 1 and
        // "Privacy Notice" on line 2 in English.
        let location = gestureRecognizer.location(in: rootView.consentLabel)
        let labelHeight = rootView.consentLabel.bounds.height

        if location.y < labelHeight / 2 {
            presenter.activateTerms()
        } else {
            presenter.activatePrivacy()
        }
    }
}

extension ConsentBannerUpgradeViewController: ConsentBannerUpgradeViewProtocol {}

extension ConsentBannerUpgradeViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension ConsentBannerUpgradeViewController: ModalCardPresentationControllerDelegate {
    // The consent banner is a legal compliance gate. The user MUST tap the
    // Accept button after checking the consent box — they cannot dismiss it
    // via swipe-down or any other gesture. Returning false here causes
    // ModalCardPresentationController.finishPresentation to cancel any
    // interactive dismissal attempt.
    func presentationControllerShouldDismiss(_: UIPresentationController) -> Bool {
        false
    }
}
