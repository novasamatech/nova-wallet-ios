import UIKit
import SoraUI
import SoraFoundation

final class NetworksViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworksViewLayout

    let presenter: NetworksPresenterProtocol

    init(
        presenter: NetworksPresenterProtocol,
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

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale

        title = R.string.localizable
            .connectionManagementTitle(preferredLanguages: locale?.rLanguages)
    }
}

extension NetworksViewController: NetworksViewProtocol {
    func reload(state: NetworksViewState) {
        print(state)
    }
}

extension NetworksViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
