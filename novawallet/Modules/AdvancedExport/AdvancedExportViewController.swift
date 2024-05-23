import UIKit
import SoraFoundation

final class AdvancedExportViewController: UIViewController, ViewHolder {
    typealias RootViewType = AdvancedExportViewLayout

    let presenter: AdvancedExportPresenterProtocol

    init(
        presenter: AdvancedExportPresenterProtocol,
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
        view = AdvancedExportViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        setupNavigationItem()
    }

    func setupLocalization() {
        setupNavigationItem()
    }

    func setupNavigationItem() {
        navigationItem.title = R.string.localizable.commonAdvanced(
            preferredLanguages: selectedLocale.rLanguages
        )
    }
}

// MARK: AdvancedExportViewProtocol

extension AdvancedExportViewController: AdvancedExportViewProtocol {
    func update(with viewModel: AdvancedExportViewLayout.Model) {
        rootView.bind(with: viewModel)
    }
    
    func updateNavbar(with viewModel: DisplayWalletViewModel) {
        let iconDetailsView: IconDetailsView = .create(with: { view in
            view.detailsLabel.apply(style: .semiboldBodyPrimary)
            view.detailsLabel.text = viewModel.name
            view.iconWidth = Constants.walletIconSize.width

            viewModel.imageViewModel?.loadImage(
                on: view.imageView,
                targetSize: Constants.walletIconSize,
                animated: true
            )
        })

        navigationItem.titleView = iconDetailsView
    }

    func showSecret(
        _ secret: String,
        for chainName: String
    ) {
        rootView.showSecret(
            secret,
            for: chainName
        )
    }
}

// MARK: Localizable

extension AdvancedExportViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}
