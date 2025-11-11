import UIKit

final class GiftClaimViewController: UIViewController, ViewHolder {
    typealias RootViewType = GiftClaimViewLayout

    let presenter: GiftClaimPresenterProtocol

    init(presenter: GiftClaimPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GiftClaimViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupActions()
        presenter.setup()
    }
}

// MARK: - Private

private extension GiftClaimViewController {
    func setupActions() {
        rootView.claimActionButton.actionButton.addTarget(
            self,
            action: #selector(actionClaim),
            for: .touchUpInside
        )
        rootView.selectedWalletControl.addTarget(
            self,
            action: #selector(actionSelectWallet),
            for: .touchUpInside
        )
    }

    @objc func actionClaim() {
        presenter.actionClaim()
    }

    @objc func actionSelectWallet() {
        presenter.actionSelectWallet()
    }
}

// MARK: - GiftPrepareShareViewProtocol

extension GiftClaimViewController: GiftClaimViewProtocol {
    func didReceive(viewModel: GiftClaimViewModel) {
        rootView.bind(viewModel: viewModel)
    }

    func didReceiveUnpacking(viewModel: LottieAnimationFrameRange) {
        rootView.bind(animationFrameRange: viewModel)
    }

    func didStartLoading() {
        rootView.bind(loading: true)
    }

    func didStopLoading() {
        rootView.bind(loading: false)
    }
}
