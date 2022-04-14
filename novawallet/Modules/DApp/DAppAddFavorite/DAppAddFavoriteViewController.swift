import UIKit

final class DAppAddFavoriteViewController: UIViewController {
    typealias RootViewType = DAppAddFavoriteViewLayout

    let presenter: DAppAddFavoritePresenterProtocol

    init(presenter: DAppAddFavoritePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppAddFavoriteViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension DAppAddFavoriteViewController: DAppAddFavoriteViewProtocol {
    func didReceive(iconViewModel: ImageViewModelProtocol) {

    }

    func didReceive(titleViewModel: InputViewModelProtocol) {

    }

    func didReceive(addressViewModel: InputViewModelProtocol) {

    }
}
