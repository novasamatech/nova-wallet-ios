import UIKit
import Foundation_iOS

final class DAppTxDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppTxDetailsViewLayout

    let presenter: DAppTxDetailsPresenterProtocol

    init(presenter: DAppTxDetailsPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppTxDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string(preferredLanguages: languages).localizable.commonTxDetails()
        rootView.titleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.dappSignOperationDetailsSubtitle()
    }
}

extension DAppTxDetailsViewController: DAppTxDetailsViewProtocol {
    func didReceive(txDetails: String) {
        rootView.detailsLabel.text = txDetails
    }
}

extension DAppTxDetailsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
