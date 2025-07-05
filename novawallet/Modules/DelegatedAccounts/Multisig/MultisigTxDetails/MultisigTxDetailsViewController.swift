import UIKit
import Foundation_iOS

final class MultisigTxDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = MultisigTxDetailsViewLayout

    let presenter: MultisigTxDetailsPresenterProtocol

    init(
        presenter: MultisigTxDetailsPresenterProtocol,
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
        view = MultisigTxDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.commonTxDetails(preferredLanguages: languages)
        rootView.titleLabel.text = R.string.localizable.dappSignOperationDetailsSubtitle(
            preferredLanguages: languages
        )
    }
}

extension MultisigTxDetailsViewController: MultisigTxDetailsViewProtocol {
    func didReceive(txDetails: String) {
        rootView.detailsLabel.text = txDetails
    }
}

extension MultisigTxDetailsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
