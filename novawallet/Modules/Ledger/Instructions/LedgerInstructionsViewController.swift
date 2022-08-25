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
