import UIKit
import Foundation_iOS

final class LedgerInstructionsViewController: UIViewController, ViewHolder {
    typealias RootViewType = LedgerInstructionsViewLayout

    let presenter: LedgerInstructionsPresenterProtocol
    let walletType: LedgerWalletType

    init(
        presenter: LedgerInstructionsPresenterProtocol,
        walletType: LedgerWalletType,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.walletType = walletType

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = LedgerInstructionsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func highlightedForStep1() -> String {
        switch walletType {
        case .legacy:
            return R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.ledgerInstructionsStep1Highlighted()
        case .generic:
            return R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.genericLedgerInstructionsStep1Highlighted()
        }
    }

    private func highlightedForStep2() -> String {
        switch walletType {
        case .legacy:
            return R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.ledgerInstructionsStep2Highlighted()
        case .generic:
            return R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.genericLedgerInstructionsStep2Highlighted()
        }
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string(preferredLanguages: languages).localizable.ledgerInstructionsTitle()

        rootView.hintLinkView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: languages
        ).localizable.ledgerInstructionsLink()

        rootView.hintLinkView.actionButton.invalidateLayout()

        rootView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: languages
        ).localizable.commonContinue()

        rootView.actionButton.invalidateLayout()

        let highlitingAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorTextPrimary()!
        ]

        let marker = AttributedReplacementStringDecorator.marker
        let step1Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [highlightedForStep1()],
            attributes: highlitingAttributes
        )

        rootView.step1.descriptionLabel.attributedText = step1Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string(preferredLanguages: languages).localizable.ledgerInstructionsStep1(marker)
            )
        )

        let step2Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [highlightedForStep2()],
            attributes: highlitingAttributes
        )

        rootView.step2.descriptionLabel.attributedText = step2Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string(preferredLanguages: languages).localizable.ledgerInstructionsStep2(marker)
            )
        )

        let step3Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [R.string(preferredLanguages: languages).localizable.ledgerInstructionsStep3Highlighted()],
            attributes: highlitingAttributes
        )

        rootView.step3.descriptionLabel.attributedText = step3Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string(preferredLanguages: languages).localizable.ledgerInstructionsStep3(marker)
            )
        )

        let step4Decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [R.string(preferredLanguages: languages).localizable.ledgerInstructionsStep4Highlighted()],
            attributes: highlitingAttributes
        )

        rootView.step4.descriptionLabel.attributedText = step4Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string(preferredLanguages: languages).localizable.ledgerInstructionsStep4(marker)
            )
        )
    }

    private func setupHandlers() {
        rootView.hintLinkView.actionButton.addTarget(
            self,
            action: #selector(actionHint),
            for: .touchUpInside
        )

        rootView.actionButton.addTarget(
            self,
            action: #selector(actionProceed),
            for: .touchUpInside
        )
    }

    @objc func actionProceed() {
        presenter.proceed()
    }

    @objc func actionHint() {
        presenter.showHint()
    }
}

extension LedgerInstructionsViewController: LedgerInstructionsViewProtocol {
    func didReceive(migrationViewModel: LedgerMigrationBannerView.ViewModel) {
        rootView.showMigrationBannerView(for: migrationViewModel)
    }
}

extension LedgerInstructionsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
