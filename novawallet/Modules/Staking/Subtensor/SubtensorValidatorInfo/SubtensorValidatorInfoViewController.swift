import Foundation_iOS
import UIKit

final class SubtensorValidatorInfoViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorValidatorInfoViewLayout

    let presenter: SubtensorValidatorInfoPresenterProtocol

    init(presenter: SubtensorValidatorInfoPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorValidatorInfoViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }
}

private extension SubtensorValidatorInfoViewController {
    func setupHandlers() {
        rootView.stakeCell.addTarget(self, action: #selector(actionStakeInfo), for: .touchUpInside)
        rootView.takeCell.addTarget(self, action: #selector(actionTakeInfo), for: .touchUpInside)
    }

    func setupLocalization() {
        title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.stakingValidatorInfoTitle()

        rootView.setupLocalization(for: selectedLocale)
    }

    @objc func actionStakeInfo() {
        presenter.showStakeInfo()
    }

    @objc func actionTakeInfo() {
        presenter.showTakeInfo()
    }
}

extension SubtensorValidatorInfoViewController: SubtensorValidatorInfoViewProtocol {
    func didReceive(viewModel: SubtensorValidatorInfoViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}

extension SubtensorValidatorInfoViewController: LoadableViewProtocol {}

extension SubtensorValidatorInfoViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
