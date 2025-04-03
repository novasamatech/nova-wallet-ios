import UIKit
import Foundation_iOS

final class SwapRouteDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapRouteDetailsViewLayout

    let presenter: SwapRouteDetailsPresenterProtocol

    init(presenter: SwapRouteDetailsPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwapRouteDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        rootView.titleView.bind(
            topValue: R.string.localizable.swapsDetailsRoute(
                preferredLanguages: selectedLocale.rLanguages
            ),
            bottomValue: R.string.localizable.swapRouteDetailsSubtitle(
                preferredLanguages: selectedLocale.rLanguages
            )
        )
    }
}

extension SwapRouteDetailsViewController: SwapRouteDetailsViewProtocol {
    func didReceive(viewModel: SwapRouteDetailsViewModel) {
        rootView.routeDetailsView.bind(viewModel: viewModel)
    }
}

extension SwapRouteDetailsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
