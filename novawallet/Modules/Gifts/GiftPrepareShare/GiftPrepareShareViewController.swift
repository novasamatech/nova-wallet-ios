import UIKit
import Foundation_iOS

final class GiftPrepareShareViewController: UIViewController, ViewHolder {
    typealias RootViewType = GiftPrepareShareViewLayout

    let presenter: GiftPrepareSharePresenterProtocol
    let localizationManager: LocalizationManagerProtocol

    let viewStyle: GiftPrepareShareViewStyle

    init(
        presenter: GiftPrepareSharePresenterProtocol,
        viewStyle: GiftPrepareShareViewStyle,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.localizationManager = localizationManager
        self.viewStyle = viewStyle
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GiftPrepareShareViewLayout(configuration: viewStyle.congifuration)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupActions()
        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // TODO: Remove after fix NovaNavigationController's actions insertion logic on setViewControllers()
        navigationController?.viewWillAppear(animated)
    }
}

// MARK: - Private

private extension GiftPrepareShareViewController {
    func setupActions() {
        rootView.shareActionButton.addTarget(
            self,
            action: #selector(actionShare),
            for: .touchUpInside
        )

        guard viewStyle == .share else { return }

        let reclaimBarButton = UIBarButtonItem(customView: rootView.reclaimActionView)
        navigationItem.setRightBarButton(reclaimBarButton, animated: true)

        rootView.reclaimActionView.actionButton.addTarget(
            self,
            action: #selector(actionReclaim),
            for: .touchUpInside
        )
    }

    func setupLocalization() {
        rootView.reclaimActionView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        ).localizable.giftActionReclaimTitle()
    }

    @objc func actionShare() {
        presenter.actionShare()
    }

    @objc func actionReclaim() {
        presenter.actionReclaim()
    }
}

// MARK: - GiftPrepareShareViewProtocol

extension GiftPrepareShareViewController: GiftPrepareShareViewProtocol {
    func didReceive(viewModel: GiftPrepareViewModel) {
        rootView.bind(viewModel: viewModel)
    }

    func didReceive(reclaimLoading: Bool) {
        guard reclaimLoading else {
            rootView.reclaimActionView.stopLoading()
            return
        }

        rootView.reclaimActionView.startLoading()
    }
}
