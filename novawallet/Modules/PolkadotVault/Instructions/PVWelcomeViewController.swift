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
        setupHints()
        setupGraphics()
        setupSegmentedControl()
        setupLocalization()
    }
}

// MARK: - Private

private extension PVWelcomeViewController {
    func setupHandlers() {
        rootView.actionButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)
        rootView.modeSegmentedControl.addTarget(self, action: #selector(actionModeChanged), for: .valueChanged)
    }

    func setupHints() {
        switch type {
        case .legacy:
            let text = R.string(preferredLanguages: selectedLocale.rLanguages)
                .localizable
                .welcomeParitySignerStep2Details()
            rootView.showStep2Hint(with: text)
        case .vault:
            rootView.hideStep2Hint()
        }
    }

    func setupGraphics() {
        switch type {
        case .legacy:
            rootView.integrationImageView.image = R.image.imageNovaParitySigner()
            rootView.step2DetailsImageView.image = R.image.imageParitySignerIntegrationHint()
        case .vault:
            rootView.integrationImageView.image = R.image.imageNovaPolkadotVault()
            rootView.step2DetailsImageView.image = R.image.imagePolkadotVaultIntegrationHint()
        }
    }

    func setupSegmentedControl() {
        let hidden = type == .legacy
        rootView.modeSegmentedControl.isHidden = hidden
    }

    func setupLocalization() {
        let localizedStrings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        rootView.titleLabel.text = localizedStrings.welcomeParitySignerTitle(
            type.getName(for: selectedLocale)
        )

        rootView.actionButton.imageWithTitleView?.title = localizedStrings.commonScanQrCode()

        rootView.actionButton.invalidateLayout()

        setupSegmentedControlLocalization()
        setupStepsLocalization(for: currentMode)
    }

    func setupSegmentedControlLocalization() {
        let localizedStrings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        rootView.modeSegmentedControl.titles = [
            localizedStrings.welcomePolkadotVaultPairPublicKey(),
            localizedStrings.welcomePolkadotVaultImportPrivateKey()
        ]
    }

    func setupStepsLocalization(for mode: PVWelcomeMode) {
        switch type {
        case .legacy:
            setupLegacyInstruction(for: selectedLocale)
        case .vault:
            setupVaultInstruction(for: selectedLocale, mode: mode)
        }
    }

    func setupLegacyInstruction(for locale: Locale) {
        let localizedStrings = R.string(preferredLanguages: locale.rLanguages).localizable
        let marker = AttributedReplacementStringDecorator.marker

        let step1Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [localizedStrings.welcomeParitySignerStep1Highlighted()],
            attributes: highlightingAttributes
        )

        rootView.step1.descriptionLabel.attributedText = step1Decorator.decorate(
            attributedString: NSAttributedString(
                string: localizedStrings.welcomeParitySignerStep1(marker)
            )
        )

        let step2Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [localizedStrings.welcomeParitySignerStep2Highlighted()],
            attributes: highlightingAttributes
        )

        rootView.step2.descriptionLabel.attributedText = step2Decorator.decorate(
            attributedString: NSAttributedString(
                string: localizedStrings.welcomeParitySignerStep2(marker)
            )
        )

        let step3Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [localizedStrings.welcomeParitySignerStep3Highlighted()],
            attributes: highlightingAttributes
        )

        rootView.step3.descriptionLabel.attributedText = step3Decorator.decorate(
            attributedString: NSAttributedString(
                string: localizedStrings.welcomeParitySignerStep3(marker)
            )
        )
    }

    func setupVaultInstruction(for locale: Locale, mode: PVWelcomeMode) {
        let localizedStrings = R.string(preferredLanguages: locale.rLanguages).localizable
        let marker = AttributedReplacementStringDecorator.marker

        let step1Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [localizedStrings.welcomePolkadotVaultStep1Highlighted()],
            attributes: highlightingAttributes
        )

        rootView.step1.descriptionLabel.attributedText = step1Decorator.decorate(
            attributedString: NSAttributedString(
                string: localizedStrings.welcomePolkadotVaultStep1(marker)
            )
        )

        switch mode {
        case .pairPublicKey:
            setupVaultPairPublicKeySteps(for: locale)
        case .importPrivateKey:
            setupVaultImportPrivateKeySteps(for: locale)
        }
    }

    func setupVaultPairPublicKeySteps(for locale: Locale) {
        let localizedStrings = R.string(preferredLanguages: locale.rLanguages).localizable
        let marker = AttributedReplacementStringDecorator.marker

        let step2Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [localizedStrings.welcomePolkadotVaultStep2PairHighlighted()],
            attributes: highlightingAttributes
        )

        rootView.step2.descriptionLabel.attributedText = step2Decorator.decorate(
            attributedString: NSAttributedString(
                string: localizedStrings.welcomePolkadotVaultStep2Pair(marker)
            )
        )

        let step3Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [localizedStrings.welcomePolkadotVaultStepLastHighlighted()],
            attributes: highlightingAttributes
        )

        rootView.step3.descriptionLabel.attributedText = step3Decorator.decorate(
            attributedString: NSAttributedString(
                string: localizedStrings.welcomePolkadotVaultStepLast(marker)
            )
        )
    }

    func setupVaultImportPrivateKeySteps(for locale: Locale) {
        let localizedStrings = R.string(preferredLanguages: locale.rLanguages).localizable
        let marker = AttributedReplacementStringDecorator.marker

        let step2Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [localizedStrings.welcomePolkadotVaultStep2PairHighlighted()],
            attributes: highlightingAttributes
        )

        rootView.step2.descriptionLabel.attributedText = step2Decorator.decorate(
            attributedString: NSAttributedString(
                string: localizedStrings.welcomePolkadotVaultStep2Pair(marker)
            )
        )

        let step3Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [localizedStrings.welcomePolkadotVaultStep3ImportHighlighted()],
            attributes: highlightingAttributes
        )

        rootView.step3.descriptionLabel.attributedText = step3Decorator.decorate(
            attributedString: NSAttributedString(
                string: localizedStrings.welcomePolkadotVaultStep3Import(marker)
            )
        )

        let step4Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [localizedStrings.welcomePolkadotVaultStepLastHighlighted()],
            attributes: highlightingAttributes
        )

        rootView.step4.descriptionLabel.attributedText = step4Decorator.decorate(
            attributedString: NSAttributedString(
                string: localizedStrings.welcomePolkadotVaultStepLast(marker)
            )
        )
    }

    @objc func actionProceed() {
        presenter.scanQr()
    }

    @objc func actionModeChanged() {
        guard let mode = PVWelcomeMode(rawValue: rootView.modeSegmentedControl.selectedSegmentIndex) else {
            return
        }

        presenter.didSelectMode(mode)
    }
}

// MARK: - PVWelcomeViewProtocol

extension PVWelcomeViewController: PVWelcomeViewProtocol {
    func didChangeMode(_ mode: PVWelcomeMode) {
        currentMode = mode
        rootView.setMode(mode)
        setupStepsLocalization(for: mode)
    }
}

// MARK: - Localizable

extension PVWelcomeViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
