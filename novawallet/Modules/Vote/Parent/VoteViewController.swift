import Foundation
import UIKit
import Foundation_iOS

final class VoteViewController: UIViewController, ViewHolder {
    typealias RootViewType = VoteViewLayout

    let presenter: VotePresenterProtocol

    private(set) var childView: VoteChildViewProtocol?

    init(
        presenter: VotePresenterProtocol,
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
        view = VoteViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()

        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.becomeOnline()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        presenter.putOffline()
    }

    private func configure() {
        rootView.headerView.chainSelectionView.addTarget(
            self,
            action: #selector(actionSelectChain),
            for: .touchUpInside
        )

        rootView.headerView.walletSwitch.addTarget(
            self,
            action: #selector(actionWalletSwitch),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        rootView.headerView.locale = selectedLocale
        childView?.locale = selectedLocale
    }

    @objc func actionSelectChain() {
        presenter.selectChain()
    }

    @objc func actionWalletSwitch() {
        presenter.selectWallet()
    }

    private func setupChildView() {
        childView?.unbind()
        childView = nil

        let governanceChildView = ReferendumsViewManager(
            tableView: rootView.tableView,
            chainSelectionView: rootView.headerView,
            parent: self
        )

        childView = governanceChildView
        childView?.bind()
        childView?.locale = selectedLocale

        presenter.switchToGovernance(governanceChildView)
    }
}

extension VoteViewController: VoteViewProtocol {
    func didSwitchWallet(with viewModel: WalletSwitchViewModel) {
        rootView.headerView.walletSwitch.bind(viewModel: viewModel)

        setupChildView()
    }

    func didReceiveGovernanceRequest() {
        setupChildView()
    }

    func showReferendumsDetails(_ index: Referenda.ReferendumIndex) {
        presenter.showReferendumsDetails(index)
    }
}

extension VoteViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension VoteViewController: HiddableBarWhenPushed {}
