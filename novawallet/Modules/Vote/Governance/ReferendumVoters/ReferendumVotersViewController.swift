import UIKit

final class ReferendumVotersViewController: UIViewController {
    typealias RootViewType = ReferendumVotersViewLayout

    let presenter: ReferendumVotersPresenterProtocol

    init(presenter: ReferendumVotersPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ReferendumVotersViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension ReferendumVotersViewController: ReferendumVotersViewProtocol {}