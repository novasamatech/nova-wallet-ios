import UIKit
import SoraFoundation

final class LedgerInstructionsViewController: UIViewController, ViewHolder {
    typealias RootViewType = LedgerInstructionsViewLayout

    let presenter: LedgerInstructionsPresenterProtocol

    init(presenter: LedgerInstructionsPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
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
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string.localizable.ledgerInstructionsTitle(preferredLanguages: languages)

        rootView.hintLinkView.actionButton.imageWithTitleView?.title = R.string.localizable.ledgerInstructionsLink(
            preferredLanguages: languages
        )

        rootView.hintLinkView.actionButton.invalidateLayout()

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: languages
        )

        rootView.actionButton.invalidateLayout()

        let highlitingAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorWhite()!
        ]

        let step1Decorator = HighlightingAttributedStringDecorator(
            pattern: R.string.localizable.ledgerInstructionsStep1Highlighted(preferredLanguages: languages),
            attributes: highlitingAttributes
        )

        rootView.step1.descriptionLabel.attributedText = step1Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string.localizable.ledgerInstructionsStep1(preferredLanguages: languages)
            )
        )

        let step2Decorator = HighlightingAttributedStringDecorator(
            pattern: R.string.localizable.ledgerInstructionsStep2Highlighted(preferredLanguages: languages),
            attributes: highlitingAttributes
        )

        rootView.step2.descriptionLabel.attributedText = step2Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string.localizable.ledgerInstructionsStep2(preferredLanguages: languages)
            )
        )

        let step3Decorator = HighlightingAttributedStringDecorator(
            pattern: R.string.localizable.ledgerInstructionsStep3Highlighted(preferredLanguages: languages),
            attributes: highlitingAttributes
        )

        rootView.step3.descriptionLabel.attributedText = step3Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string.localizable.ledgerInstructionsStep3(preferredLanguages: languages)
            )
        )

        let step4Decorator = HighlightingAttributedStringDecorator(
            pattern: R.string.localizable.ledgerInstructionsStep4Highlighted(preferredLanguages: languages),
            attributes: highlitingAttributes
        )

        rootView.step4.descriptionLabel.attributedText = step4Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string.localizable.ledgerInstructionsStep4(preferredLanguages: languages)
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

extension LedgerInstructionsViewController: LedgerInstructionsViewProtocol {}

extension LedgerInstructionsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
