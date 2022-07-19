import UIKit
import SoraFoundation
import SoraUI

final class OnboardingMainViewController: UIViewController, ViewHolder {
    typealias RootViewType = OnboardingMainViewLayout

    let presenter: OnboardingMainPresenterProtocol
    let termDecorator: AttributedStringDecoratorProtocol

    init(
        presenter: OnboardingMainPresenterProtocol,
        termDecorator: AttributedStringDecoratorProtocol,
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
        view = OnboardingMainViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        let createTitle = R.string.localizable.onboardingCreateWallet(preferredLanguages: languages)
        rootView.createButton.bind(title: createTitle, details: nil)

        let importTitle = R.string.localizable.onboardingRestoreWallet(preferredLanguages: languages)
        let importSubtitle = R.string.localizable.welcomeImportSubtitle(preferredLanguages: languages)
        rootView.importButton.bind(title: importTitle, details: importSubtitle)

        let watchOnlyTitle = R.string.localizable.welcomeWatchOnlyTitle(preferredLanguages: languages)
        let watchOnlySubtitle = R.string.localizable.welcomeWatchOnlySubtitle(preferredLanguages: languages)
        rootView.watchOnlyButton.bind(title: watchOnlyTitle, details: watchOnlySubtitle)

        let termsText = R.string.localizable.onboardingTermsAndConditions1_v2_2_0(
            preferredLanguages: languages
        )

        let attributedText = NSAttributedString(string: termsText)
        rootView.termsLabel.attributedText = termDecorator.decorate(attributedString: attributedText)
    }

    private func setupHandlers() {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(actionTerms(gestureRecognizer:)))
        rootView.termsLabel.addGestureRecognizer(tapRecognizer)

        rootView.createButton.addTarget(self, action: #selector(actionSignup), for: .touchUpInside)
        rootView.importButton.addTarget(self, action: #selector(actionRestoreAccess), for: .touchUpInside)
        rootView.watchOnlyButton.addTarget(self, action: #selector(actionCreateWatchOnly), for: .touchUpInside)
    }

    @objc private func actionSignup() {
        presenter.activateSignup()
    }

    @objc private func actionRestoreAccess() {
        presenter.activateAccountRestore()
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

    @objc private func actionCreateWatchOnly() {}
}

extension OnboardingMainViewController: OnboardingMainViewProtocol {}

extension OnboardingMainViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
