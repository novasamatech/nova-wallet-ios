import UIKit
import SoraFoundation

final class StartStakingInfoViewController: UIViewController, ViewHolder {
    typealias RootViewType = StartStakingInfoViewLayout

    let presenter: StartStakingInfoPresenterProtocol
    private var viewModel: LoadableViewModelState<StartStakingViewModel>?
    private var balance = ""

    init(
        presenter: StartStakingInfoPresenterProtocol,
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
        view = StartStakingInfoViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {
        rootView.updateBalanceButton(
            text: balance,
            locale: selectedLocale
        )

        guard let viewModel = viewModel?.value else {
            return
        }

        rootView.updateContent(
            title: viewModel.title,
            paragraphs: viewModel.paragraphs,
            wikiUrl: viewModel.wikiUrl,
            termsUrl: viewModel.termsUrl
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if viewModel?.isLoading == true {
            rootView.updateLoadingState()
            rootView.skeletonView?.restartSkrulling()
        }
    }
}

extension StartStakingInfoViewController: StartStakingInfoViewProtocol {
    func didReceive(viewModel: LoadableViewModelState<StartStakingViewModel>) {
        switch viewModel {
        case .loading:
            rootView.startLoadingIfNeeded()
            rootView.actionView.startLoading()
        case let .cached(value), let .loaded(value):
            rootView.stopLoadingIfNeeded()
            rootView.actionView.stopLoading()
            rootView.updateContent(
                title: value.title,
                paragraphs: value.paragraphs,
                wikiUrl: value.wikiUrl,
                termsUrl: value.termsUrl
            )
        }

        self.viewModel = viewModel
    }

    func didReceive(balance: String) {
        self.balance = balance
        rootView.updateBalanceButton(text: balance, locale: selectedLocale)
    }
}

extension StartStakingInfoViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else {
            return
        }
        setupLocalization()
    }
}
