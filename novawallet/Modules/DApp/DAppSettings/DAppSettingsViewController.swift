import UIKit

final class DAppSettingsViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppSettingsViewLayout

    let presenter: DAppSettingsPresenterProtocol

    var preferredHeight: CGFloat {
        rootView.preferredHeight
    }

    init(presenter: DAppSettingsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppSettingsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.favoriteRow.addTarget(self, action: #selector(didTapOnFavorite), for: .touchUpInside)
        rootView.desktopModeRow.switchView.addTarget(
            self,
            action: #selector(didChangeDesktopMode),
            for: .valueChanged
        )
        presenter.setup()
    }

    @objc private func didTapOnFavorite() {
        presenter.presentFavorite()
    }

    @objc private func didChangeDesktopMode(control: UISwitch) {
        presenter.changeDesktopMode(isOn: control.isOn)
    }
}

extension DAppSettingsViewController: DAppSettingsViewProtocol {
    func update(title: String) {
        rootView.titleRow.titleLabel.text = title
    }

    func update(favoriteModel: TitleIconViewModel) {
        rootView.favoriteRow.iconDetailsView.bind(viewModel: favoriteModel)
    }

    func updateDesktopModel(_ titleModel: TitleIconViewModel, isOn: Bool) {
        rootView.desktopModeRow.iconDetailsView.bind(viewModel: titleModel)
        rootView.desktopModeRow.switchView.isOn = isOn
    }
}
