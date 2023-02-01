import UIKit

final class DelegateInfoDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = DelegateInfoDetailsViewLayout

    let presenter: DelegateInfoDetailsPresenterProtocol

    init(presenter: DelegateInfoDetailsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DelegateInfoDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension DelegateInfoDetailsViewController: DelegateInfoDetailsViewProtocol {
    func didReceive(viewModel: DelegateInfoDetailsState) {
        navigationItem.title = viewModel.name
        rootView.activityIndicator.startAnimating()
        rootView.descriptionView.load(from: viewModel.longDescription) { [weak self] text in
            guard text != nil else {
                return
            }
            self?.rootView.activityIndicator.stopAnimating()
        }
    }
}
