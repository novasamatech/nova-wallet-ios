import UIKit
import SoraFoundation

final class NftListViewController: UIViewController, ViewHolder {
    typealias RootViewType = NftListViewLayout

    let presenter: NftListPresenterProtocol

    init(presenter: NftListPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NftListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.walletListYourNftsTitle(preferredLanguages: selectedLocale.rLanguages)
    }
}

extension NftListViewController: NftListViewProtocol {}

extension NftListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
