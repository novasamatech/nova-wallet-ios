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

        setupHandlers()
        presenter.setup()
    }

    private func setupHandlers() {
        rootView.markdownView.onTouchLink = { [weak self] request in
            guard let url = request.url, url.scheme == "https" else {
                return false
            }
            self?.presenter.open(url: url)
            return false
        }
    }
}

extension ReferendumFullDescriptionViewController: ReferendumFullDescriptionViewProtocol {
    func didReceive(title: String, description: String) {
        rootView.set(title: title)
        rootView.set(markdownText: description)
    }
}
