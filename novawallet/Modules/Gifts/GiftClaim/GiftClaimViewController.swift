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
        rootView.claimActionButton.addTarget(
            self,
            action: #selector(actionClaim),
            for: .touchUpInside
        )
    }

    @objc func actionClaim() {
        presenter.actionClaim()
    }
}

// MARK: - GiftPrepareShareViewProtocol

extension GiftClaimViewController: GiftClaimViewProtocol {
    func didReceive(viewModel: GiftClaimViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}
