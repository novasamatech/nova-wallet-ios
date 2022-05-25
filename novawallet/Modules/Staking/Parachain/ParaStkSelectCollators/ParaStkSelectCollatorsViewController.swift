import UIKit
import SoraFoundation

final class ParaStkSelectCollatorsViewController: UIViewController, ViewHolder {
    typealias RootViewType = ParaStkSelectCollatorsViewLayout

    let presenter: ParaStkSelectCollatorsPresenterProtocol

    init(
        presenter: ParaStkSelectCollatorsPresenterProtocol,
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
        view = ParaStkSelectCollatorsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBarItems()
        setupLocalization()

        presenter.setup()
    }

    private func setupBarItems() {
        navigationItem.rightBarButtonItems = [rootView.searchButton, rootView.filterButton]

        rootView.searchButton.target = self
        rootView.searchButton.action = #selector(actionSearch)

        rootView.filterButton.target = self
        rootView.filterButton.action = #selector(actionFilter)
    }

    private func setupLocalization() {
        title = R.string.localizable.parachainStakingSelectCollator(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.clearButton.imageWithTitleView?.title = R.string.localizable.stakingCustomClearButtonTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.clearButton.invalidateLayout()
    }

    @objc private func actionSearch() {}

    @objc private func actionFilter() {}
}

extension ParaStkSelectCollatorsViewController: ParaStkSelectCollatorsViewProtocol {}

extension ParaStkSelectCollatorsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
