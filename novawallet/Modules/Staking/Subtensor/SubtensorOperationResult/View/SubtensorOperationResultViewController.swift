import UIKit
import Foundation_iOS

final class SubtensorOperationResultViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorOperationResultViewLayout

    let presenter: SubtensorResultPresenterProtocol

    private var currentAction: SubtensorResultAction?
    private var currentStatus: SubtensorResultStatus?

    init(presenter: SubtensorResultPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorOperationResultViewLayout()
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

private extension SubtensorOperationResultViewController {
    func setupHandlers() {
        rootView.detailsView.delegate = self

        rootView.backButton.addTarget(self, action: #selector(actionBack), for: .touchUpInside)
        rootView.detailsView.swapRateCell.addTarget(self, action: #selector(actionSwapRate), for: .touchUpInside)
        rootView.detailsView.costBasisCell.addTarget(self, action: #selector(actionCostBasis), for: .touchUpInside)
        rootView.detailsView.slippageCell.addTarget(self, action: #selector(actionSlippage), for: .touchUpInside)
        rootView.detailsView.validatorCell.addTarget(self, action: #selector(actionValidator), for: .touchUpInside)
        rootView.detailsView.networkFeeCell.addTarget(self, action: #selector(actionNetworkFee), for: .touchUpInside)
    }

    func setupLocalization() {
        rootView.detailsView.setup(locale: selectedLocale)
    }

    func bindAction(_ action: SubtensorResultActionViewModel?) {
        currentAction = action?.action

        guard let action else {
            rootView.removeActionButton()
            return
        }

        let button = rootView.setupActionButton(title: action.title)
        button.addTarget(self, action: #selector(actionMain), for: .touchUpInside)
    }

    @objc func actionBack() {
        presenter.goBack()
    }

    @objc func actionMain() {
        guard let currentAction else {
            return
        }

        presenter.activate(action: currentAction)
    }

    @objc func actionSwapRate() {
        presenter.showInfo(for: .swapRate)
    }

    @objc func actionCostBasis() {
        presenter.showInfo(for: .costBasis)
    }

    @objc func actionSlippage() {
        presenter.showInfo(for: .slippage)
    }

    @objc func actionValidator() {
        presenter.showInfo(for: .validator)
    }

    @objc func actionNetworkFee() {
        presenter.showInfo(for: .networkFee)
    }
}

extension SubtensorOperationResultViewController: SubtensorResultViewProtocol {
    func didReceive(viewModel: SubtensorOperationResultViewModel) {
        guard case let .page(pageViewModel) = viewModel else {
            return
        }

        rootView.statusView.bind(viewModel: pageViewModel.status)
        rootView.pairsView.leftAssetView.bind(viewModel: pageViewModel.payTile)
        rootView.pairsView.rigthAssetView.bind(viewModel: pageViewModel.receiveTile)
        rootView.detailsView.bind(viewModel: pageViewModel.details, locale: selectedLocale)
        rootView.backButton.isHidden = !pageViewModel.showsBack

        if currentStatus != pageViewModel.status.status {
            currentStatus = pageViewModel.status.status
            rootView.detailsView.setExpanded(pageViewModel.details.isExpanded, animated: false)
        }

        if currentAction != pageViewModel.action?.action {
            bindAction(pageViewModel.action)
        } else if let title = pageViewModel.action?.title {
            rootView.actionButton?.imageWithTitleView?.title = title
        }
    }

    func didUpdateCountdown(remainedTime: UInt) {
        rootView.statusView.updateProgress(remainedTime: remainedTime)
    }
}

extension SubtensorOperationResultViewController: CollapsableContainerViewDelegate {
    func animateAlongsideWithInfo(sender _: AnyObject?) {
        rootView.containerView.scrollView.layoutIfNeeded()
    }

    func didChangeExpansion(isExpanded _: Bool, sender _: AnyObject) {}
}

extension SubtensorOperationResultViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
