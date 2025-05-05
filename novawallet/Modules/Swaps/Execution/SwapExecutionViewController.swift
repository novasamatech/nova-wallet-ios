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

    private func setupHandlers() {
        rootView.detailsView.delegate = self

        rootView.rateCell.addTarget(self, action: #selector(rateAction), for: .touchUpInside)
        rootView.routeCell.addTarget(self, action: #selector(routeAction), for: .touchUpInside)
        rootView.priceDifferenceCell.addTarget(self, action: #selector(priceDifferenceAction), for: .touchUpInside)
        rootView.slippageCell.addTarget(self, action: #selector(slippageAction), for: .touchUpInside)
        rootView.totalFeeCell.addTarget(self, action: #selector(totalFeeAction), for: .touchUpInside)
    }

    private func setupLocalization() {
        rootView.setup(locale: selectedLocale)
    }

    @objc private func rateAction() {
        presenter.showRateInfo()
    }

    @objc private func priceDifferenceAction() {
        presenter.showPriceDifferenceInfo()
    }

    @objc private func routeAction() {
        presenter.showRouteDetails()
    }

    @objc private func slippageAction() {
        presenter.showSlippageInfo()
    }

    @objc private func totalFeeAction() {
        presenter.showTotalFeeInfo()
    }

    @objc private func actionDone() {
        presenter.activateDone()
    }

    @objc private func actionTryAgain() {
        presenter.activateTryAgain()
    }
}

extension SwapExecutionViewController: SwapExecutionViewProtocol {
    func didReceiveExecution(viewModel: SwapExecutionViewModel) {
        rootView.statusView.bind(viewModel: viewModel, locale: selectedLocale)

        switch viewModel {
        case .completed:
            let doneButton = rootView.setupDoneButton(for: selectedLocale)
            doneButton.addTarget(self, action: #selector(actionDone), for: .touchUpInside)
        case .failed:
            let tryAgainButton = rootView.setupTryAgainButton(for: selectedLocale)
            tryAgainButton.addTarget(self, action: #selector(actionTryAgain), for: .touchUpInside)
        case .inProgress:
            break
        }
    }

    func didUpdateExecution(remainedTime: UInt) {
        rootView.statusView.updateProgress(remainedTime: remainedTime)
    }

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

extension SwapExecutionViewController: CollapsableContainerViewDelegate {
    func animateAlongsideWithInfo(sender _: AnyObject?) {
        rootView.containerView.scrollView.layoutIfNeeded()
    }

    func didChangeExpansion(isExpanded _: Bool, sender _: AnyObject) {}
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
