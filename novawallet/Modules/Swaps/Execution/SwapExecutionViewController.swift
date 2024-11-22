import UIKit
import SoraFoundation

final class SwapExecutionViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapExecutionViewLayout

    let presenter: SwapExecutionPresenterProtocol

    init(
        presenter: SwapExecutionPresenterProtocol,
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
        view = SwapExecutionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        rootView.setup(locale: selectedLocale)
    }
}

extension SwapExecutionViewController: SwapExecutionViewProtocol {
    func didReceive(countdownViewModel: CountdownLoadingView.ViewModel) {
        rootView.countdownView.start(with: countdownViewModel)
    }

    func didReceive(currentOperation: String) {
        rootView.statusTitleView.bind(
            viewModel: .init(
                topValue: R.string.localizable.swapsExecutionDontCloseApp(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                bottomValue: currentOperation
            )
        )
    }

    func didReceive(executing _: UInt, total _: UInt) {}

    func didReceiveAssetIn(viewModel: SwapAssetAmountViewModel) {
        rootView.pairsView.leftAssetView.bind(viewModel: viewModel)
    }

    func didReceiveAssetOut(viewModel: SwapAssetAmountViewModel) {
        rootView.pairsView.rigthAssetView.bind(viewModel: viewModel)
    }

    func didReceiveRate(viewModel: LoadableViewModelState<String>) {
        rootView.rateCell.bind(loadableViewModel: viewModel)
    }

    func didReceiveRoute(viewModel: LoadableViewModelState<[SwapRouteItemView.ItemViewModel]>) {
        rootView.routeCell.bind(loadableRouteViewModel: viewModel)
    }

    func didReceivePriceDifference(viewModel: LoadableViewModelState<DifferenceViewModel>?) {
        if let viewModel {
            rootView.priceDifferenceCell.isHidden = false
            rootView.priceDifferenceCell.bind(differenceViewModel: viewModel)
        } else {
            rootView.priceDifferenceCell.isHidden = true
        }
    }

    func didReceiveSlippage(viewModel: String) {
        rootView.slippageCell.bind(loadableViewModel: .loaded(value: viewModel))
    }

    func didReceiveTotalFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>) {
        rootView.totalFeeCell.bind(loadableViewModel: viewModel)
    }
}

extension SwapExecutionViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
