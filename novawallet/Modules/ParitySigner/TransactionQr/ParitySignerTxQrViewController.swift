import UIKit

final class ParitySignerTxQrViewController: UIViewController {
    typealias RootViewType = ParitySignerTxQrViewLayout

    let presenter: ParitySignerTxQrPresenterProtocol

    init(presenter: ParitySignerTxQrPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ParitySignerTxQrViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        title = "Sign with Parity Signer"
    }
}

extension ParitySignerTxQrViewController: ParitySignerTxQrViewProtocol {}
