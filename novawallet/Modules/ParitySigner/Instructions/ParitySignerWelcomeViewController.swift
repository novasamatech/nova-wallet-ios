import UIKit
import SoraFoundation

final class ParitySignerWelcomeViewController: UIViewController, ViewHolder {
    typealias RootViewType = ParitySignerWelcomeViewLayout

    let presenter: ParitySignerWelcomePresenterProtocol
    let type: ParitySignerType

    let highlightingAttributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: R.color.colorTextPrimary()!
    ]

    init(
        presenter: ParitySignerWelcomePresenterProtocol,
        type: ParitySignerType,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.type = type

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ParitySignerWelcomeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupGraphics()
        setupLocalization()
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)
    }

    private func setupGraphics() {
        switch type {
        case .legacy:
            rootView.integrationImageView.image = R.image.imageNovaParitySigner()
            rootView.step2DetailsImageView.image = R.image.imageParitySignerIntegrationHint()
        case .vault:
            rootView.integrationImageView.image = R.image.imageNovaPolkadotVault()
            rootView.step2DetailsImageView.image = R.image.imagePolkadotVaultIntegrationHint()
        }
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string.localizable.welcomeParitySignerTitle(
            type.getName(for: selectedLocale),
            preferredLanguages: languages
        )

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonScanQrCode(
            preferredLanguages: languages
        )

        rootView.actionButton.invalidateLayout()

        switch type {
        case .legacy:
            setupLegacyInstruction(for: selectedLocale)
        case .vault:
            setupVaultInstruction(for: selectedLocale)
        }
    }

    private func setupLegacyInstruction(for locale: Locale) {
        let languages = locale.rLanguages

        let step1Decorator = HighlightingAttributedStringDecorator(
            pattern: R.string.localizable.welcomeParitySignerStep1Highlighted(preferredLanguages: languages),
            attributes: highlightingAttributes
        )

        rootView.step1.descriptionLabel.attributedText = step1Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string.localizable.welcomeParitySignerStep1(preferredLanguages: languages)
            )
        )

        let step2Decorator = HighlightingAttributedStringDecorator(
            pattern: R.string.localizable.welcomeParitySignerStep2Highlighted(preferredLanguages: languages),
            attributes: highlightingAttributes
        )

        rootView.step2.descriptionLabel.attributedText = step2Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string.localizable.welcomeParitySignerStep2(preferredLanguages: languages)
            )
        )

        rootView.step2DetailsView.detailsLabel.text = R.string.localizable.welcomeParitySignerStep2Details(
            preferredLanguages: languages
        )

        let step3Decorator = HighlightingAttributedStringDecorator(
            pattern: R.string.localizable.welcomeParitySignerStep3Highlighted(preferredLanguages: languages),
            attributes: highlightingAttributes
        )

        rootView.step3.descriptionLabel.attributedText = step3Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string.localizable.welcomeParitySignerStep3(preferredLanguages: languages)
            )
        )
    }

    private func setupVaultInstruction(for locale: Locale) {
        let languages = locale.rLanguages

        let step1Decorator = HighlightingAttributedStringDecorator(
            pattern: R.string.localizable.welcomePolkadotVaultStep1Highlighted(preferredLanguages: languages),
            attributes: highlightingAttributes
        )

        rootView.step1.descriptionLabel.attributedText = step1Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string.localizable.welcomePolkadotVaultStep1(preferredLanguages: languages)
            )
        )

        let step2Decorator = HighlightingAttributedStringDecorator(
            pattern: R.string.localizable.welcomePolkadotVaultStep2Highlighted(preferredLanguages: languages),
            attributes: highlightingAttributes
        )

        rootView.step2.descriptionLabel.attributedText = step2Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string.localizable.welcomePolkadotVaultStep2(preferredLanguages: languages)
            )
        )

        rootView.step2DetailsView.detailsLabel.text = R.string.localizable.welcomePolkadotVaultStep2Details(
            preferredLanguages: languages
        )

        let step3Decorator = HighlightingAttributedStringDecorator(
            pattern: R.string.localizable.welcomePolkadotVaultStep3Highlighted(preferredLanguages: languages),
            attributes: highlightingAttributes
        )

        rootView.step3.descriptionLabel.attributedText = step3Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string.localizable.welcomePolkadotVaultStep3(preferredLanguages: languages)
            )
        )
    }

    @objc private func actionProceed() {
        presenter.scanQr()
    }
}

extension ParitySignerWelcomeViewController: ParitySignerWelcomeViewProtocol {}

extension ParitySignerWelcomeViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
