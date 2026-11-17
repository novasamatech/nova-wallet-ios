import UIKit
import Foundation_iOS

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

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        rootView.statusView.updateAnimationOnAppear()
    }
}

private extension SwapExecutionViewController {
    func setupHandlers() {
        rootView.routeCell.addTarget(self, action: #selector(routeAction), for: .touchUpInside)
        rootView.closeButton.addTarget(self, action: #selector(closeAction), for: .touchUpInside)
    }

    func setupLocalization() {
        rootView.setup(locale: selectedLocale)
    }

    @objc func routeAction() {
        presenter.showRouteDetails()
    }

    @objc func closeAction() {
        presenter.activateClose()
    }

    @objc func doneAction() {
        presenter.activateDone()
    }

    @objc func tryAgainAction() {
        presenter.activateTryAgain()
    }

    @objc func viewTransactionAction() {
        presenter.showFailedTransaction()
    }
}

extension SwapExecutionViewController: SwapExecutionViewProtocol {
    func didReceiveExecution(viewModel: SwapExecutionViewModel) {
        rootView.statusView.bind(viewModel: viewModel, locale: selectedLocale)

        switch viewModel {
        case .completed:
            rootView.setFinished(isSuccess: true)

            let doneButton = rootView.setupDoneButton(for: selectedLocale)
            doneButton.addTarget(self, action: #selector(doneAction), for: .touchUpInside)
        case .failed:
            rootView.setFinished(isSuccess: false)

            let tryAgainButton = rootView.setupTryAgainButton(for: selectedLocale)
            tryAgainButton.addTarget(self, action: #selector(tryAgainAction), for: .touchUpInside)
        case .inProgress:
            break
        }
    }

    func didUpdateExecution(remainedTime: UInt) {
        rootView.statusView.updateProgress(remainedTime: remainedTime)
    }

    func didReceiveAssetIn(viewModel: SwapAssetAmountViewModel) {
        rootView.pairsView.payCardView.bind(viewModel: viewModel)
    }

    func didReceiveAssetOut(viewModel: SwapAssetAmountViewModel) {
        rootView.pairsView.receiveCardView.bind(viewModel: viewModel)
    }

    func didReceiveRate(viewModel: LoadableViewModelState<String>) {
        rootView.rateCell.bind(loadableViewModel: viewModel)
    }

    func didReceiveRoute(viewModel: LoadableViewModelState<[SwapRouteItemView.ItemViewModel]>) {
        rootView.routeCell.bind(loadableRouteViewModel: viewModel)
    }

    func didReceiveTotalFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>) {
        rootView.totalFeeCell.bind(loadableFeeViewModel: viewModel)
    }

    func didReceiveSteps(viewModel: [SwapExecutionStepViewModel]) {
        rootView.stepsView.isHidden = viewModel.isEmpty
        rootView.stepsView.bind(viewModel: viewModel, locale: selectedLocale)
        rootView.stepsView.viewTransactionButton?.addTarget(
            self,
            action: #selector(viewTransactionAction),
            for: .touchUpInside
        )
    }
}

extension SwapExecutionViewController: ModalCardPresentationControllerDelegate {
    func presentationControllerShouldDismiss(_: UIPresentationController) -> Bool {
        false
    }
}

extension SwapExecutionViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
