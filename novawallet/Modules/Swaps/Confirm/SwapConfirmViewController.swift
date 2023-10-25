import UIKit
import SoraFoundation

final class SwapConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapConfirmViewLayout

    let presenter: SwapConfirmPresenterProtocol

    init(
        presenter: SwapConfirmPresenterProtocol,
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
        view = SwapConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        presenter.setup()
    }

    private func setupLocalization() {
        rootView.setup(locale: selectedLocale)
    }

    private func setupHandlers() {}
}

extension SwapConfirmViewController: SwapConfirmViewProtocol {
    func didReceiveAssetIn(viewModel: SwapAssetAmountViewModel) {
        rootView.pairsView.leftAssetView.bind(viewModel: viewModel)
    }

    func didReceiveAssetOut(viewModel: SwapAssetAmountViewModel) {
        rootView.pairsView.rigthAssetView.bind(viewModel: viewModel)
    }

    func didReceiveRate(viewModel: LoadableViewModelState<String>) {
        rootView.rateCell.bind(loadableViewModel: viewModel)
    }

    func didReceivePriceDifference(viewModel: LoadableViewModelState<DifferenceViewModel>?) {
        if let viewModel = viewModel {
            rootView.priceDifferenceCell.isHidden = false
            rootView.priceDifferenceCell.bind(differenceViewModel: viewModel)
        } else {
            rootView.priceDifferenceCell.isHidden = true
        }
    }

    func didReceiveSlippage(viewModel: String) {
        rootView.slippageCell.bind(loadableViewModel: .loaded(value: viewModel))
    }

    func didReceiveNetworkFee(viewModel: LoadableViewModelState<SwapFeeViewModel>) {
        rootView.networkFeeCell.bind(loadableViewModel: viewModel)
    }

    func didReceiveWallet(viewModel: WalletAccountViewModel?) {
        guard let viewModel = viewModel else {
            rootView.walletTableView.isHidden = true
            return
        }
        rootView.walletTableView.isHidden = false
        rootView.walletCell.bind(viewModel: .init(
            details: viewModel.walletName ?? "",
            imageViewModel: viewModel.walletIcon
        ))

        rootView.accountCell.bind(viewModel: .init(
            details: viewModel.address,
            imageViewModel: viewModel.addressIcon
        ))
    }
}

extension SwapConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
