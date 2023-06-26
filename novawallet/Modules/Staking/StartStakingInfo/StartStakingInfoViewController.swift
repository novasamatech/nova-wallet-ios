import UIKit
import SoraFoundation

final class StartStakingInfoViewController: UIViewController, ViewHolder {
    typealias RootViewType = StartStakingInfoViewLayout

    let presenter: StartStakingInfoPresenterProtocol
    private var viewModel: LoadableViewModelState<StartStakingViewModel>?

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
            text: "",
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
}

extension StartStakingInfoViewController: StartStakingInfoViewProtocol {
    func didReceive(viewModel: LoadableViewModelState<StartStakingViewModel>) {
        switch viewModel {
        case .loading:
            rootView.actionView.startLoading()
        case let .cached(value), let .loaded(value):
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
