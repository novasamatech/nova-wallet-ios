import UIKit
import SoraFoundation

final class AssetDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = AssetDetailsViewLayout

    let presenter: AssetDetailsPresenterProtocol
    var observable = NovaWalletViewModelObserverContainer<ContainableObserver>()
    weak var reloadableDelegate: ReloadableDelegate?
    var contentInsets: UIEdgeInsets = .zero
    var preferredContentHeight: CGFloat { rootView.prefferedHeight }

    init(
        presenter: AssetDetailsPresenterProtocol,
        localizableManager: LocalizationManagerProtocol
    ) {
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

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rootView.chainView)
        addHandlers()
        applyLocalization()
        presenter.setup()
    }

    private func addHandlers() {
        rootView.sendButton.addTarget(self, action: #selector(didTapSendButton), for: .touchUpInside)
        rootView.receiveButton.addTarget(self, action: #selector(didTapReceiveButton), for: .touchUpInside)
        rootView.buyButton.addTarget(self, action: #selector(didTapBuyButton), for: .touchUpInside)
        rootView.lockCell.addTarget(self, action: #selector(didTapLocks), for: .touchUpInside)
    }

    @objc private func didTapSendButton() {
        presenter.handleSend()
    }

    @objc private func didTapReceiveButton() {
        presenter.handleReceive()
    }

    @objc private func didTapBuyButton() {
        presenter.handleBuy()
    }

    @objc private func didTapLocks() {
        presenter.handleLocks()
    }
}

extension AssetDetailsViewController: AssetDetailsViewProtocol {
    func didReceive(assetModel: AssetDetailsModel) {
        rootView.set(assetDetailsModel: assetModel)
    }

    func didReceive(totalBalance: BalanceViewModelProtocol) {
        rootView.totalCell.bind(viewModel: totalBalance)
    }

    func didReceive(transferableBalance: BalanceViewModelProtocol) {
        rootView.transferrableCell.bind(viewModel: transferableBalance)
    }

    func didReceive(lockedBalance: BalanceViewModelProtocol, isSelectable: Bool) {
        rootView.lockCell.bind(viewModel: lockedBalance)
        rootView.lockCell.canSelect = isSelectable
    }

    func didReceive(availableOperations: AssetDetailsOperation) {
        rootView.sendButton.isEnabled = availableOperations.contains(.send)
        rootView.receiveButton.isEnabled = availableOperations.contains(.receive)
        rootView.buyButton.isEnabled = availableOperations.contains(.buy)
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
