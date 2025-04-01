import UIKit
import Foundation_iOS

final class AssetDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = AssetDetailsViewLayout

    let chartViewProvider: AssetPriceChartViewProviderProtocol
    let presenter: AssetDetailsPresenterProtocol
    var observable = NovaWalletViewModelObserverContainer<ContainableObserver>()
    weak var reloadableDelegate: ReloadableDelegate?
    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            rootView.setBottomInset(contentInsets.bottom)
        }
    }

    var preferredContentHeight: CGFloat { rootView.prefferedHeight }

    init(
        chartViewProvider: AssetPriceChartViewProviderProtocol,
        presenter: AssetDetailsPresenterProtocol,
        localizableManager: LocalizationManagerProtocol
    ) {
        self.chartViewProvider = chartViewProvider
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        localizationManager = localizableManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AssetDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        applyLocalization()
        presenter.setup()
    }
}

private extension AssetDetailsViewController {
    func setupView() {
        setupChartView()
        addHandlers()

        rootView.delegate = self
    }

    func setupChartView() {
        let insets = UIEdgeInsets(
            inset: AssetDetailsViewLayout.Constants.chartWidgetInset
        )
        chartViewProvider.setupView(
            on: self,
            view: rootView.chartContainerView,
            insets: insets
        )
    }

    func addHandlers() {
        rootView.sendButton.addTarget(self, action: #selector(didTapSendButton), for: .touchUpInside)
        rootView.receiveButton.addTarget(self, action: #selector(didTapReceiveButton), for: .touchUpInside)
        rootView.buyButton.addTarget(self, action: #selector(didTapBuyButton), for: .touchUpInside)
        rootView.swapButton.addTarget(self, action: #selector(didTapSwapButton), for: .touchUpInside)
        rootView.balanceWidget.lockCell.addTarget(self, action: #selector(didTapLocks), for: .touchUpInside)
    }

    @objc func didTapSendButton() {
        presenter.handleSend()
    }

    @objc func didTapReceiveButton() {
        presenter.handleReceive()
    }

    @objc func didTapBuyButton() {
        presenter.handleBuy()
    }

    @objc func didTapSwapButton() {
        presenter.handleSwap()
    }

    @objc func didTapLocks() {
        presenter.handleLocks()
    }
}

extension AssetDetailsViewController: AssetDetailsViewProtocol {
    func didReceive(assetModel: AssetDetailsModel) {
        rootView.set(assetDetailsModel: assetModel)
    }

    func didReceive(availableOperations: AssetDetailsOperation) {
        rootView.sendButton.isEnabled = availableOperations.contains(.send)
        rootView.receiveButton.isEnabled = availableOperations.contains(.receive)
        rootView.swapButton.isEnabled = availableOperations.contains(.swap)
        rootView.buyButton.isEnabled = availableOperations.contains(.buy)
    }

    func didReceive(balance: AssetDetailsBalanceModel) {
        rootView.balanceWidget.bind(with: balance)
    }

    func didReceiveChartAvailable(_ available: Bool) {
        let widgetHeight = available
            ? chartViewProvider.getProposedHeight()
            : .zero

        rootView.setChartViewHeight(widgetHeight)

        observable.observers.forEach {
            $0.observer?.didChangePreferredContentHeight(to: preferredContentHeight)
        }
    }
}

extension AssetDetailsViewController: AssetDetailsViewLayoutDelegate {
    func didUpdateHeight(_ height: CGFloat) {
        observable.observers.forEach {
            $0.observer?.didChangePreferredContentHeight(to: height)
        }
    }
}

extension AssetDetailsViewController: Containable {
    func setContentInsets(_ insets: UIEdgeInsets, animated _: Bool) {
        contentInsets = insets
    }

    var contentView: UIView {
        view
    }
}

extension AssetDetailsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.set(locale: selectedLocale)
        }
    }
}
