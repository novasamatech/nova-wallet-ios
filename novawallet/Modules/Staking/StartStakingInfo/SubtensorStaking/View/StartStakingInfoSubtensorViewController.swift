import Foundation_iOS
import UIKit

final class StartStakingInfoSubtensorViewController: UIViewController, ViewHolder {
    typealias RootViewType = StartStakingInfoSubtensorViewLayout

    let presenter: StartStakingInfoSubtensorPresenterProtocol
    let themeColor: UIColor

    init(
        presenter: StartStakingInfoSubtensorPresenterProtocol,
        themeColor: UIColor,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.themeColor = themeColor

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StartStakingInfoSubtensorViewLayout(themeColor: themeColor)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupActions()
        presenter.setup()
    }
}

private extension StartStakingInfoSubtensorViewController {
    func setupActions() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionStartStaking),
            for: .touchUpInside
        )
    }

    @objc func actionStartStaking() {
        presenter.startStaking()
    }
}

extension StartStakingInfoSubtensorViewController: StartStakingInfoSubtensorViewProtocol {
    func didReceive(subtensorViewModel: StartStakingInfoSubtensorViewModel) {
        rootView.bind(viewModel: subtensorViewModel)
    }

    func didReceive(viewModel _: LoadableViewModelState<StartStakingViewModel>) {}

    func didReceive(balance: String) {
        rootView.balanceLabel.text = balance
    }

    func didReceive(announcement _: AnnouncementViewModel?) {}
}

extension StartStakingInfoSubtensorViewController: SubtensorEarnFlowRoot {
    func startSubnetDiscovery() {
        presenter.startStaking()
    }
}

extension StartStakingInfoSubtensorViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else {
            return
        }

        presenter.refreshContent()
    }
}
