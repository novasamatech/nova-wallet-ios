import UIKit

final class DAppSearchViewController: UIViewController {
    typealias RootViewType = DAppSearchViewLayout

    let presenter: DAppSearchPresenterProtocol

    let searchBar: UISearchBar = {
        let view = UISearchBar()
        view.setBackgroundImage(UIImage(), for: .top, barMetrics: .default)
        return view
    }()

    init(presenter: DAppSearchPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppSearchViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupSearchBar()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        searchBar.becomeFirstResponder()
    }

    private func setupSearchBar() {
        navigationItem.titleView = searchBar

        searchBar.delegate = self
    }
}

extension DAppSearchViewController: DAppSearchViewProtocol {}

extension DAppSearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let input = searchBar.text else {
            return
        }

        presenter.activateBrowser(for: input)
    }
}
