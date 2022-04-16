import UIKit

final class DAppAuthSettingsViewController: UIViewController {
    typealias RootViewType = DAppAuthSettingsViewLayout

    let presenter: DAppAuthSettingsPresenterProtocol

    init(presenter: DAppAuthSettingsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppAuthSettingsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension DAppAuthSettingsViewController: DAppAuthSettingsViewProtocol {}