import Foundation_iOS
import UIKit

final class SubtensorPortfolioViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorPortfolioViewLayout

    let presenter: SubtensorPortfolioPresenterProtocol

    init(
        presenter: SubtensorPortfolioPresenterProtocol,
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
        view = SubtensorPortfolioViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }
}

private extension SubtensorPortfolioViewController {
    func setupHandlers() {
        rootView.addButton.addTarget(self, action: #selector(actionAdd), for: .touchUpInside)
        rootView.syncNoticeControl.addTarget(self, action: #selector(actionRetry), for: .touchUpInside)
        rootView.headerView.periodControl.addTarget(self, action: #selector(actionPeriod), for: .valueChanged)

        rootView.onSelectPosition = { [weak self] index in
            self?.presenter.selectPosition(at: index)
        }
    }

    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        title = strings.stakingSubtensorUiPortfolioTitle()

        let ratesUnavailable = strings.stakingSubtensorUiPortfolioRatesUnavailable()

        rootView.headerView.captionLabel.text = strings.stakingSubtensorUiPortfolioTotal()
        rootView.headerView.ratesAlertView.contentView.detailsLabel.text = ratesUnavailable
        rootView.positionsCaptionLabel.text = strings.stakingSubtensorUiPortfolioPositions()
        rootView.syncNoticeLabel.text = strings.stakingSubtensorUiPortfolioSyncFailed()

        let emptyView = rootView.emptyView
        emptyView.captionLabel.text = strings.stakingSubtensorUiPortfolioEmptyCaption()
        emptyView.ratesAlertView.contentView.detailsLabel.text = ratesUnavailable
        emptyView.subnetCardView.titleLabel.text = strings.stakingSubtensorUiPortfolioEmptySubnetTitle()
        emptyView.subnetCardView.subtitleLabel.text = strings.stakingSubtensorUiPortfolioEmptySubnetSubtitle()
        emptyView.rootCardView.titleLabel.text = strings.stakingSubtensorUiPortfolioEmptyRootTitle()
        emptyView.unstakeCardView.titleLabel.text = strings.stakingSubtensorUiPortfolioEmptyUnstakeTitle()
        emptyView.unstakeCardView.subtitleLabel.text = strings.stakingSubtensorUiPortfolioEmptyUnstakeSubtitle()

        rootView.addButton.imageWithTitleView?.title = strings.stakingSubtensorUiPortfolioAdd()
        rootView.addButton.invalidateLayout()
    }

    @objc func actionAdd() {
        presenter.addPosition()
    }

    @objc func actionRetry() {
        presenter.retry()
    }

    @objc func actionPeriod() {
        presenter.selectPeriod(at: rootView.headerView.periodControl.selectedSegmentIndex)
    }
}

extension SubtensorPortfolioViewController: SubtensorPortfolioViewProtocol {
    func didReceive(viewModel: SubtensorPortfolioViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}

extension SubtensorPortfolioViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
