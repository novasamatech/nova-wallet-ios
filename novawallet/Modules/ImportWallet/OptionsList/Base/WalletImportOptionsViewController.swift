import UIKit
import Foundation_iOS

final class WalletImportOptionsViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletImportOptionsViewLayout

    let presenter: WalletImportOptionsPresenterProtocol

    init(
        presenter: WalletImportOptionsPresenterProtocol,
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
        view = WalletImportOptionsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {
        rootView.titleLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.walletImportTitle()
    }
}

extension WalletImportOptionsViewController: WalletImportOptionsViewProtocol {
    func didReceive(viewModel: WalletImportOptionViewModel) {
        rootView.apply(viewModel: viewModel)
    }
}

extension WalletImportOptionsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
