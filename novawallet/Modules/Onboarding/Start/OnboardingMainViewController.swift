import UIKit
import Foundation_iOS
import UIKit_iOS

final class OnboardingMainViewController: UIViewController, ViewHolder {
    typealias RootViewType = OnboardingMainViewLayout

    let presenter: OnboardingMainPresenterProtocol

    init(
        presenter: OnboardingMainPresenterProtocol,
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
        view = OnboardingMainViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        applyConsentState()

        presenter.setup()
    }

    private func applyConsentState() {
        let isAccepted = rootView.consentCheckbox.isSelected
        rootView.createButton.isEnabled = isAccepted
        rootView.importButton.isEnabled = isAccepted
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        let createTitle = R.string(preferredLanguages: languages).localizable.onboardingCreateWallet()
        rootView.createButton.imageWithTitleView?.title = createTitle

        let importTitle = R.string(preferredLanguages: languages).localizable.onboardingRestoreWallet()
        rootView.importButton.imageWithTitleView?.title = importTitle

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
        rootView.termsLabel.attributedText = consentDecorator.decorate(attributedString: attributedText)
    }

    private func setupHandlers() {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(actionTerms(gestureRecognizer:)))
        rootView.termsLabel.addGestureRecognizer(tapRecognizer)

        rootView.consentCheckbox.addTarget(self, action: #selector(actionToggleConsent), for: .touchUpInside)
        rootView.createButton.addTarget(self, action: #selector(actionSignup), for: .touchUpInside)
        rootView.importButton.addTarget(self, action: #selector(actionRestoreAccess), for: .touchUpInside)
    }

    @objc private func actionToggleConsent() {
        rootView.consentCheckbox.isSelected.toggle()
        applyConsentState()
    }

    @objc private func actionSignup() {
        presenter.activateSignup()
    }

    @objc private func actionRestoreAccess() {
        presenter.activateAccountRestore()
    }

    @objc private func actionTerms(gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .ended else { return }

        // The Aurum-mandated text wraps such that "Terms of Service" lands on the
        // first line and "Privacy Notice" on the second. We detect which link the
        // user tapped using vertical position. If the wording is ever revised so
        // that wrapping changes, this heuristic must be revisited.
        let location = gestureRecognizer.location(in: rootView.termsLabel)
        let labelHeight = rootView.termsLabel.bounds.height

        if location.y < labelHeight / 2 {
            presenter.activateTerms()
        } else {
            presenter.activatePrivacy()
        }
    }
}

extension OnboardingMainViewController: OnboardingMainViewProtocol {}

extension OnboardingMainViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
