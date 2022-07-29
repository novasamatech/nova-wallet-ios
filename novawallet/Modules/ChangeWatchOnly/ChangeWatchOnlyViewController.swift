import UIKit
import SoraFoundation

final class ChangeWatchOnlyViewController: UIViewController, ViewHolder {
    typealias RootViewType = ChangeWatchOnlyViewLayout

    let presenter: ChangeWatchOnlyPresenterProtocol

    init(presenter: ChangeWatchOnlyPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ChangeWatchOnlyViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {

    }
}

extension ChangeWatchOnlyViewController: ChangeWatchOnlyViewProtocol {}

extension ChangeWatchOnlyViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
