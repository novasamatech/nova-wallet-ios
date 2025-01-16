import UIKit
import Foundation_iOS

final class SwapFeeDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapFeeDetailsViewLayout

    let presenter: SwapFeeDetailsPresenterProtocol

    init(
        presenter: SwapFeeDetailsPresenterProtocol,
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
        view = SwapFeeDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }
}

private extension SwapFeeDetailsViewController {
    func setupLocalization() {
        rootView.totalFeeView.titleView.text = R.string.localizable.swapsDetailsTotalFee(
            preferredLanguages: selectedLocale.rLanguages
        )
    }
}

extension SwapFeeDetailsViewController: SwapFeeDetailsViewProtocol {
    func didReceive(viewModel: SwapFeeDetailsViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}

extension SwapFeeDetailsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
