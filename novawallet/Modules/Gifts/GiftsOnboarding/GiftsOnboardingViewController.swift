import UIKit
import Foundation_iOS

final class GiftsOnboardingViewController: UIViewController, ViewHolder {
    typealias RootViewType = GiftsOnboardingViewLayout

    let presenter: GiftsOnboardingPresenterProtocol

    init(
        presenter: GiftsOnboardingPresenterProtocol,
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
        view = GiftsOnboardingViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        presenter.setup()
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionProceed),
            for: .touchUpInside
        )

        rootView.learnMoreView.actionButton.addTarget(
            self,
            action: #selector(actionLearnMore),
            for: .touchUpInside
        )
    }

    @objc private func actionProceed() {
        presenter.proceed()
    }

    @objc private func actionLearnMore() {
        presenter.activateLearnMore()
    }
}

extension GiftsOnboardingViewController: GiftsOnboardingViewProtocol {
    func didReceive(viewModel: GiftsOnboardingViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}

extension GiftsOnboardingViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            presenter.setup()
        }
    }
}
