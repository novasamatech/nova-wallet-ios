import UIKit

final class ReferendumFullDescriptionViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReferendumFullDescriptionViewLayout

    let presenter: ReferendumFullDescriptionPresenterProtocol

    init(presenter: ReferendumFullDescriptionPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ReferendumFullDescriptionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension ReferendumFullDescriptionViewController: ReferendumFullDescriptionViewProtocol {
    func didReceive(title: String, description: String) {
        rootView.set(title: title)
        rootView.set(markdownText: description)
    }
}
