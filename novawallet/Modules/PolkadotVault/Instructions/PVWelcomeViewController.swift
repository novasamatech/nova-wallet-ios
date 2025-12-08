import UIKit
import Foundation_iOS

final class PVWelcomeViewController: UIViewController, ViewHolder {
    typealias RootViewType = PVWelcomeViewLayout

    let presenter: PVWelcomePresenterProtocol
    let type: ParitySignerType

    private var currentMode: PVWelcomeMode = .pairPublicKey

    let highlightingAttributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: R.color.colorTextPrimary()!
    ]

    init(
        presenter: PVWelcomePresenterProtocol,
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
        view = PVWelcomeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupGraphics()
        setupLocalization()
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)
        rootView.modeSegmentedControl.addTarget(self, action: #selector(actionModeChanged), for: .valueChanged)
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

        rootView.titleLabel.text = R.string(preferredLanguages: languages).localizable.welcomeParitySignerTitle(
            type.getName(for: selectedLocale)
        )

        rootView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: languages
        ).localizable.commonScanQrCode()

        rootView.actionButton.invalidateLayout()

        setupSegmentedControlLocalization()
        setupStepsLocalization(for: currentMode)
    }

    private func setupSegmentedControlLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.modeSegmentedControl.titles = [
            R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultPairPublicKey(),
            R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultImportPrivateKey()
        ]
    }

    private func setupStepsLocalization(for mode: PVWelcomeMode) {
        switch type {
        case .legacy:
            setupLegacyInstruction(for: selectedLocale, mode: mode)
        case .vault:
            setupVaultInstruction(for: selectedLocale, mode: mode)
        }
    }

    private func setupLegacyInstruction(for locale: Locale, mode: PVWelcomeMode) {
        let languages = locale.rLanguages
        let marker = AttributedReplacementStringDecorator.marker

        // Step 1: Open Parity Signer application on your smartphone
        let step1Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [R.string(preferredLanguages: languages).localizable.welcomeParitySignerStep1Highlighted()],
            attributes: highlightingAttributes
        )

        rootView.step1.descriptionLabel.attributedText = step1Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string(preferredLanguages: languages).localizable.welcomeParitySignerStep1(marker)
            )
        )

        switch mode {
        case .pairPublicKey:
            setupLegacyPairPublicKeySteps(for: locale)
        case .importPrivateKey:
            setupLegacyImportPrivateKeySteps(for: locale)
        }
    }

    private func setupLegacyPairPublicKeySteps(for locale: Locale) {
        let languages = locale.rLanguages
        let marker = AttributedReplacementStringDecorator.marker

        // Step 2: Tap on Derived Key you would like to add to Nova Wallet
        let step2Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStep2PairHighlighted()],
            attributes: highlightingAttributes
        )

        rootView.step2.descriptionLabel.attributedText = step2Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStep2Pair(marker)
            )
        )

        // Step 3: Parity Signer will provide you QR code to scan
        let step3Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [R.string(preferredLanguages: languages).localizable.welcomeParitySignerStep3Highlighted()],
            attributes: highlightingAttributes
        )

        rootView.step3.descriptionLabel.attributedText = step3Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string(preferredLanguages: languages).localizable.welcomeParitySignerStep3(marker)
            )
        )
    }

    private func setupLegacyImportPrivateKeySteps(for locale: Locale) {
        let languages = locale.rLanguages
        let marker = AttributedReplacementStringDecorator.marker

        // Step 2: Tap on Derived Key you would like to add to Nova Wallet
        let step2Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStep2PairHighlighted()],
            attributes: highlightingAttributes
        )

        rootView.step2.descriptionLabel.attributedText = step2Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStep2Pair(marker)
            )
        )

        // Step 3: Tap the icon in the top-right corner and select Export Private Key
        let step3Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStep3ImportHighlighted()],
            attributes: highlightingAttributes
        )

        rootView.step3.descriptionLabel.attributedText = step3Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStep3Import(marker)
            )
        )

        // Step 4: Parity Signer will provide you QR code to scan
        let step4Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [R.string(preferredLanguages: languages).localizable.welcomeParitySignerStep3Highlighted()],
            attributes: highlightingAttributes
        )

        rootView.step4.descriptionLabel.attributedText = step4Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string(preferredLanguages: languages).localizable.welcomeParitySignerStep3(marker)
            )
        )
    }

    private func setupVaultInstruction(for locale: Locale, mode: PVWelcomeMode) {
        let languages = locale.rLanguages
        let marker = AttributedReplacementStringDecorator.marker

        // Step 1: Open Polkadot Vault application on your smartphone
        let step1Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStep1Highlighted()],
            attributes: highlightingAttributes
        )

        rootView.step1.descriptionLabel.attributedText = step1Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStep1(marker)
            )
        )

        switch mode {
        case .pairPublicKey:
            setupVaultPairPublicKeySteps(for: locale)
        case .importPrivateKey:
            setupVaultImportPrivateKeySteps(for: locale)
        }
    }

    private func setupVaultPairPublicKeySteps(for locale: Locale) {
        let languages = locale.rLanguages
        let marker = AttributedReplacementStringDecorator.marker

        // Step 2: Tap on Derived Key you would like to add to Nova Wallet
        let step2Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStep2PairHighlighted()],
            attributes: highlightingAttributes
        )

        rootView.step2.descriptionLabel.attributedText = step2Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStep2Pair(marker)
            )
        )

        // Step 3: Polkadot Vault will provide you QR code to scan
        let step3Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStepLastHighlighted()],
            attributes: highlightingAttributes
        )

        rootView.step3.descriptionLabel.attributedText = step3Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStepLast(marker)
            )
        )
    }

    private func setupVaultImportPrivateKeySteps(for locale: Locale) {
        let languages = locale.rLanguages
        let marker = AttributedReplacementStringDecorator.marker

        // Step 2: Tap on Derived Key you would like to add to Nova Wallet
        let step2Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStep2PairHighlighted()],
            attributes: highlightingAttributes
        )

        rootView.step2.descriptionLabel.attributedText = step2Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStep2Pair(marker)
            )
        )

        // Step 3: Tap the icon in the top-right corner and select Export Private Key
        let step3Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStep3ImportHighlighted()],
            attributes: highlightingAttributes
        )

        rootView.step3.descriptionLabel.attributedText = step3Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStep3Import(marker)
            )
        )

        // Step 4: Polkadot Vault will provide you QR code to scan
        let step4Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStepLastHighlighted()],
            attributes: highlightingAttributes
        )

        rootView.step4.descriptionLabel.attributedText = step4Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string(preferredLanguages: languages).localizable.welcomePolkadotVaultStepLast(marker)
            )
        )
    }

    @objc private func actionProceed() {
        presenter.scanQr()
    }

    @objc private func actionModeChanged() {
        guard let mode = PVWelcomeMode(rawValue: rootView.modeSegmentedControl.selectedSegmentIndex) else {
            return
        }

        presenter.didSelectMode(mode)
    }
}

extension PVWelcomeViewController: PVWelcomeViewProtocol {
    func didChangeMode(_ mode: PVWelcomeMode) {
        currentMode = mode
        rootView.setMode(mode)
        setupStepsLocalization(for: mode)
    }
}

extension PVWelcomeViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
