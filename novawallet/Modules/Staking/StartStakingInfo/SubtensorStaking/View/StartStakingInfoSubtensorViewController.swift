import Foundation_iOS
import UIKit

final class StartStakingInfoSubtensorViewController: UIViewController, ViewHolder {
    typealias RootViewType = StartStakingInfoSubtensorViewLayout

    let presenter: StartStakingInfoSubtensorPresenterProtocol

    init(
        presenter: StartStakingInfoSubtensorPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StartStakingInfoSubtensorViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupActions()
        rootView.setLoading(true)
        presenter.setup()
    }
}

private extension StartStakingInfoSubtensorViewController {
    func setupActions() {
        rootView.primaryButton.addTarget(
            self,
            action: #selector(actionStartEarning),
            for: .touchUpInside
        )
        rootView.secondaryButton.addTarget(
            self,
            action: #selector(actionChooseManually),
            for: .touchUpInside
        )
    }

    @objc func actionStartEarning() {
        presenter.startStaking()
    }

    @objc func actionChooseManually() {
        presenter.chooseManually()
    }
}

extension StartStakingInfoSubtensorViewController: StartStakingInfoSubtensorViewProtocol {
    func didReceive(subtensorViewModel: LoadableViewModelState<StartStakingInfoSubtensorViewModel>) {
        switch subtensorViewModel {
        case .loading:
            rootView.setLoading(true)
        case let .cached(value), let .loaded(value):
            rootView.bind(viewModel: value)
            rootView.setLoading(false)
        }
    }

    func didReceive(viewModel _: LoadableViewModelState<StartStakingViewModel>) {}

    func didReceive(balance: String) {
        rootView.balanceLabel.text = balance
    }

    func didReceive(announcement _: AnnouncementViewModel?) {}
}

extension StartStakingInfoSubtensorViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else {
            return
        }

        presenter.refreshContent()
    }
}
