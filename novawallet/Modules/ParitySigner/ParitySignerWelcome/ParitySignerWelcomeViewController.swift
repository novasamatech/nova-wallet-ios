import UIKit
import SoraFoundation

final class ParitySignerWelcomeViewController: UIViewController, ViewHolder {
    typealias RootViewType = ParitySignerWelcomeViewLayout

    let presenter: ParitySignerWelcomePresenterProtocol

    init(presenter: ParitySignerWelcomePresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
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

        setupLocalization()
    }

    private func setupLocalization() {
        let highlitingAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorWhite()!
        ]

        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string.localizable.welcomeParitySignerTitle(preferredLanguages: languages)

        let step1Decorator = HighlightingAttributedStringDecorator(
            pattern: R.string.localizable.welcomeParitySignerStep1Highlighted(preferredLanguages: languages),
            attributes: highlitingAttributes
        )

        rootView.step1.descriptionLabel.attributedText = step1Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string.localizable.welcomeParitySignerStep1(preferredLanguages: languages)
            )
        )

        let step2Decorator = HighlightingAttributedStringDecorator(
            pattern: R.string.localizable.welcomeParitySignerStep2Highlighted(preferredLanguages: languages),
            attributes: highlitingAttributes
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
            attributes: highlitingAttributes
        )

        rootView.step3.descriptionLabel.attributedText = step3Decorator.decorate(
            attributedString: NSAttributedString(
                string: R.string.localizable.welcomeParitySignerStep3(preferredLanguages: languages)
            )
        )

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonScanQrCode(
            preferredLanguages: languages
        )

        rootView.actionButton.invalidateLayout()
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
