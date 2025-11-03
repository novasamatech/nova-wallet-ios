import UIKit

final class GiftPrepareShareViewController: UIViewController, ViewHolder {
    typealias RootViewType = GiftPrepareShareViewLayout

    let presenter: GiftPrepareSharePresenterProtocol

    let viewStyle: GiftPrepareShareViewStyle

    init(
        presenter: GiftPrepareSharePresenterProtocol,
        viewStyle: GiftPrepareShareViewStyle
    ) {
        self.presenter = presenter
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

        presenter.setup()
    }
}

// MARK: - GiftPrepareShareViewProtocol

extension GiftPrepareShareViewController: GiftPrepareShareViewProtocol {
    func didReceive(viewModel: GiftPrepareViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}
