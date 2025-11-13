import UIKit
import Foundation_iOS

final class GiftsOnboardingViewController: UIViewController, ViewHolder {
    typealias RootViewType = GiftsOnboardingViewLayout

    let presenter: GiftsOnboardingPresenterProtocol

    init(presenter: GiftsOnboardingPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GiftsOnboardingViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        presenter.setup()
    }
}

// MARK: - Private

private extension GiftsOnboardingViewController {
    func setupHandlers() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionProceed),
            for: .touchUpInside
        )

        rootView.headerView.learnMoreView.actionButton.addTarget(
            self,
            action: #selector(actionLearnMore),
            for: .touchUpInside
        )
    }

    @objc func actionProceed() {
        presenter.proceed()
    }

    @objc func actionLearnMore() {
        presenter.activateLearnMore()
    }
}

// MARK: - GiftsOnboardingViewProtocol

extension GiftsOnboardingViewController: GiftsOnboardingViewProtocol {
    func didReceive(viewModel: GiftsOnboardingViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}
