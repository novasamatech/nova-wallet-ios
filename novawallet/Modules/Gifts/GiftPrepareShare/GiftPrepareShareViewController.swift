import UIKit

final class GiftPrepareShareViewController: UIViewController, ViewHolder {
    typealias RootViewType = GiftPrepareShareViewLayout

    let presenter: GiftPrepareSharePresenterProtocol

    init(presenter: GiftPrepareSharePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GiftPrepareShareViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension GiftPrepareShareViewController: GiftPrepareShareViewProtocol {
    func didReceive(viewModel: GiftPrepareViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}
