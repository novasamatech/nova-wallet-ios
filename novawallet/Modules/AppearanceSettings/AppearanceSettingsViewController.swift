import UIKit

final class AppearanceSettingsViewController: UIViewController, ViewHolder {
    typealias RootViewType = AppearanceSettingsViewLayout

    let presenter: AppearanceSettingsPresenterProtocol

    init(presenter: AppearanceSettingsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AppearanceSettingsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension AppearanceSettingsViewController: AppearanceSettingsViewProtocol {}
