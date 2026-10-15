import Foundation_iOS
import UIKit

final class SubtensorSubnetDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorSubnetDetailsViewLayout

    let presenter: SubtensorSubnetDetailsPresenterProtocol

    private let seekHapticPlayer: ProgressiveHapticPlayer
    private let chartLongPressHapticPlayer: HapticPlayer
    private let periodControlHapticPlayer: HapticPlayer

    private var titleImageViewModel: ImageViewModelProtocol?

    init(
        presenter: SubtensorSubnetDetailsPresenterProtocol,
        seekHapticPlayer: ProgressiveHapticPlayer,
        chartLongPressHapticPlayer: HapticPlayer,
        periodControlHapticPlayer: HapticPlayer,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.seekHapticPlayer = seekHapticPlayer
        self.chartLongPressHapticPlayer = chartLongPressHapticPlayer
        self.periodControlHapticPlayer = periodControlHapticPlayer

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorSubnetDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }
}

private extension SubtensorSubnetDetailsViewController {
    enum Constants {
        static let titleIconSize = CGSize(width: 24, height: 24)
        static let titleSpacing: CGFloat = 8
    }

    func setupHandlers() {
        rootView.currencyControl.addTarget(self, action: #selector(actionCurrency), for: .valueChanged)
        rootView.periodControl.addTarget(self, action: #selector(actionPeriod), for: .valueChanged)
        rootView.chartUnavailableView.addTarget(self, action: #selector(actionRetryHistory), for: .touchUpInside)
        rootView.chartView.delegate = self
        rootView.validatorView.addTarget(self, action: #selector(actionValidator), for: .touchUpInside)
        rootView.favoriteButton.addTarget(self, action: #selector(actionFavorite), for: .touchUpInside)
        rootView.actionButton.addTarget(self, action: #selector(actionUseSubnet), for: .touchUpInside)

        rootView.moreDetailsView.delegate = self
    }

    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        rootView.validatorCaptionLabel.applySubtensorCaps(strings.stakingSubtensorV22Validators())
        rootView.parametersHeadingLabel.applySubtensorCaps(strings.stakingSubtensorV22Parameters())

        rootView.moreDetailsView.titleControl.titleLabel.text = strings.stakingSubtensorUiDetailMore()
        rootView.moreDetailsView.titleControl.invalidateLayout()

        rootView.actionButton.imageWithTitleView?.title = strings.stakingSubtensorUiDetailUseSubnet()
        rootView.actionButton.invalidateLayout()
    }

    @objc func actionCurrency() {
        presenter.selectCurrency(at: rootView.currencyControl.selectedSegmentIndex)
    }

    @objc func actionPeriod() {
        periodControlHapticPlayer.play()
        presenter.selectPeriod(at: rootView.periodControl.selectedSegmentIndex)
    }

    @objc func actionRetryHistory() {
        presenter.retryHistory()
    }

    @objc func actionValidator() {
        presenter.selectValidator()
    }

    @objc func actionFavorite() {
        presenter.toggleFavorite()
    }

    @objc func actionUseSubnet() {
        presenter.useSubnet()
    }
}

extension SubtensorSubnetDetailsViewController: SubtensorSubnetDetailsViewProtocol {
    func didReceive(title: SubtensorSubnetDetailsTitleViewModel) {
        if let titleView = navigationItem.titleView as? IconDetailsView {
            titleImageViewModel?.cancel(on: titleView.imageView)
        }

        let titleView: IconDetailsView = .create { view in
            view.detailsLabel.apply(style: .semiboldBodyPrimary)
            view.detailsLabel.text = title.title
            view.imageView.contentMode = .scaleAspectFit
            view.iconWidth = Constants.titleIconSize.width
            view.spacing = Constants.titleSpacing
            view.imageView.snp.makeConstraints { $0.height.equalTo(Constants.titleIconSize.height) }
        }

        titleImageViewModel = title.icon
        title.icon.loadImage(on: titleView.imageView, targetSize: Constants.titleIconSize, animated: true)

        navigationItem.titleView = titleView
    }

    func didReceive(viewModel: SubtensorSubnetDetailsViewModel) {
        rootView.priceWidget.bind(viewModel: viewModel.priceWidget)
        rootView.validatorView.bind(viewModel: viewModel.validator)
        rootView.parametersView.bind(viewModel.parameters)
        rootView.moreDetailsView.bind(viewModel.moreDetails)

        rootView.favoriteButton.imageWithTitleView?.iconImage = viewModel.isFavorite
            ? R.image.iconFavToolbarSel()
            : R.image.iconFavToolbar()?.tinted(with: R.color.colorIconSecondary()!)
        rootView.favoriteButton.accessibilityLabel = viewModel.favoriteAccessibilityLabel
        rootView.favoriteButton.invalidateLayout()

        rootView.actionButton.isEnabled = viewModel.isUseEnabled

        if viewModel.isUseEnabled {
            rootView.actionButton.applyEnabledStyle()
        } else {
            rootView.actionButton.applyDisabledStyle()
        }
    }

    func didReceive(priceHeader: SubtensorSubnetPriceHeaderViewModel) {
        rootView.priceWidget.bind(header: priceHeader)
    }
}

extension SubtensorSubnetDetailsViewController: SubtensorPriceChartViewDelegate {
    func priceChartViewDidBeginSelection(_: SubtensorSubnetPriceChartView) {
        chartLongPressHapticPlayer.play()
    }

    func priceChartView(_: SubtensorSubnetPriceChartView, didSelect selection: SubtensorPriceChartSelection) {
        seekHapticPlayer.play()
        presenter.selectChart(selection)
    }

    func priceChartViewDidEndSelection(_: SubtensorSubnetPriceChartView) {
        seekHapticPlayer.reset()
        presenter.selectChart(nil)
    }
}

extension SubtensorSubnetDetailsViewController: CollapsableContainerViewDelegate {
    func animateAlongsideWithInfo(sender _: AnyObject?) {
        rootView.containerView.scrollView.layoutIfNeeded()
    }

    func didChangeExpansion(isExpanded _: Bool, sender _: AnyObject) {}
}

extension SubtensorSubnetDetailsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
