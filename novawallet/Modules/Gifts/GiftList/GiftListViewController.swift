import UIKit
import Foundation_iOS

final class GiftListViewController: UIViewController, ViewHolder {
    typealias RootViewType = GiftListViewLayout

    let presenter: GiftListPresenterProtocol
    let localizationManager: LocalizationManagerProtocol

    init(
        presenter: GiftListPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.localizationManager = localizationManager
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GiftListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        setupLocalization()
    }
}

// MARK: - Private

private extension GiftListViewController {
    func setupLocalization() {
        rootView.loadingView.titleLabel.text = R.string(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        ).localizable.giftLoadingMessage()
    }

    func setupOnboardingHandlers() {
        rootView.onboardingView.actionButton.removeTarget(
            self,
            action: #selector(actionCreateGift),
            for: .touchUpInside
        )
        rootView.onboardingView.headerView.learnMoreView.actionButton.removeTarget(
            self,
            action: #selector(actionLearnMore),
            for: .touchUpInside
        )
        rootView.onboardingView.actionButton.addTarget(
            self,
            action: #selector(actionCreateGift),
            for: .touchUpInside
        )
        rootView.onboardingView.headerView.learnMoreView.actionButton.addTarget(
            self,
            action: #selector(actionLearnMore),
            for: .touchUpInside
        )
    }

    @objc func actionCreateGift() {
        presenter.actionCreateGift()
    }

    @objc func actionLearnMore() {
        presenter.activateLearnMore()
    }
}

// MARK: - GiftListViewProtocol

extension GiftListViewController: GiftListViewProtocol {
    func didReceive(viewModel: GiftsOnboardingViewModel) {
        rootView.bind(loading: false)
        rootView.bind(viewModel: viewModel)

        setupOnboardingHandlers()
    }

    func didReceive(loading: Bool) {
        rootView.bind(loading: loading)
    }
}
