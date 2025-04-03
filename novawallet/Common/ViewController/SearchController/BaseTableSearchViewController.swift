import UIKit
import UIKit_iOS

class BaseTableSearchViewController: UIViewController, ViewHolder {
    typealias RootViewType = BaseTableSearchViewLayout

    let basePresenter: TableSearchPresenterProtocol

    lazy var searchActivityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.color = R.color.colorIndicatorShimmering()!
        return activityIndicator
    }()

    // MARK: - Lifecycle

    init(basePresenter: TableSearchPresenterProtocol) {
        self.basePresenter = basePresenter

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = BaseTableSearchViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupSearchView()

        basePresenter.setup()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        rootView.searchField.resignFirstResponder()
    }

    // MARK: - Private functions

    private func setupSearchView() {
        rootView.searchField.delegate = self
    }
}

extension BaseTableSearchViewController: TableSearchViewProtocol {
    func didStartSearch() {
        rootView.searchField.rightViewMode = .always
        rootView.searchField.rightView = searchActivityIndicator
        searchActivityIndicator.startAnimating()
    }

    func didStopSearch() {
        searchActivityIndicator.stopAnimating()
        rootView.searchField.rightView = nil
    }
}

// MARK: - UITextFieldDelegate

extension BaseTableSearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        guard let text = textField.text else { return false }

        basePresenter.search(for: text)
        return false
    }

    func textFieldShouldClear(_: UITextField) -> Bool {
        basePresenter.search(for: "")
        return true
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let text = textField.text as NSString? else {
            return true
        }

        let newString = text.replacingCharacters(in: range, with: string)
        basePresenter.search(for: newString)

        return true
    }
}
