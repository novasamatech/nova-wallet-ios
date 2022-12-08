import UIKit
import SoraFoundation

final class AssetDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = AssetDetailsViewLayout

    let presenter: AssetDetailsPresenterProtocol

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

        applyLocalization()
        addHandlers()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rootView.chainView)
        presenter.setup()
    }

    private func addHandlers() {
        rootView.sendButton.addTarget(self, action: #selector(didTapSendButton), for: .touchUpInside)
        rootView.receiveButton.addTarget(self, action: #selector(didTapReceiveButton), for: .touchUpInside)
        rootView.buyButton.addTarget(self, action: #selector(didTapBuyButton), for: .touchUpInside)
        rootView.lockCell.addTarget(self, action: #selector(didTapLocks), for: .touchUpInside)
    }

    @objc func didTapSendButton() {
        presenter.didTapSendButton()
    }

    @objc func didTapReceiveButton() {
        presenter.didTapReceiveButton()
    }

    @objc func didTapBuyButton() {
        presenter.didTapBuyButton()
    }

    @objc func didTapLocks() {
        presenter.didTapLocks()
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

    func didReceive(availableOperations: Operations) {
        rootView.sendButton.isEnabled = availableOperations.contains(.send)
        rootView.receiveButton.isEnabled = availableOperations.contains(.receive)
        rootView.buyButton.isEnabled = availableOperations.contains(.buy)
    }
}

struct Operations: OptionSet {
    let rawValue: Int

    static let send = Operations(rawValue: 1 << 0)
    static let receive = Operations(rawValue: 1 << 1)
    static let buy = Operations(rawValue: 1 << 2)
    static let all = [Operations.send, Operations.receive, Operations.buy]
}

extension AssetDetailsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.set(locale: selectedLocale)
        }
    }
}
