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

        navigationItem.titleView = rootView.titleView

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }
}

private extension SubtensorSubnetDetailsViewController {
    enum Constants {
        static let titleIconSize = CGSize(width: 24, height: 24)
    }

    func setupHandlers() {
        rootView.currencyControl.addTarget(self, action: #selector(actionCurrency), for: .valueChanged)
        rootView.periodControl.addTarget(self, action: #selector(actionPeriod), for: .valueChanged)
        rootView.chartUnavailableView.addTarget(self, action: #selector(actionRetryHistory), for: .touchUpInside)
        rootView.chartView.delegate = self
        rootView.validatorView.addTarget(self, action: #selector(actionValidator), for: .touchUpInside)
        rootView.favoriteButton.addTarget(self, action: #selector(actionFavorite), for: .touchUpInside)
        rootView.actionButton.addTarget(self, action: #selector(actionUseSubnet), for: .touchUpInside)

        rootView.estimateView.chipButtons.forEach { button in
            button.addTarget(self, action: #selector(actionChip(_:)), for: .touchUpInside)
        }

        rootView.moreDetailsView.delegate = self
    }

    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        rootView.validatorCaptionLabel.text = strings.stakingSubtensorUiDetailValidator()
        rootView.validatorView.titleLabel.text = strings.stakingCommonValidator()
        rootView.estimateCaptionLabel.text = strings.stakingSubtensorUiDetailEstimate()
        rootView.estimateView.noteLabel.text = strings.stakingSubtensorUiDetailEstimateNote()

        rootView.moreDetailsView.titleControl.titleLabel.text = strings.stakingSubtensorUiDetailMore()
        rootView.moreDetailsView.titleControl.invalidateLayout()
        rootView.moreDetailsView.numberCell.titleLabel.text = strings.stakingSubtensorUiPickerNumber()

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

    @objc func actionChip(_ sender: UIControl) {
        presenter.selectAmount(at: sender.tag)
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
        let titleView = rootView.titleView

        titleImageViewModel?.cancel(on: titleView.imageView)
        titleImageViewModel = title.icon

        titleView.detailsLabel.text = title.title
        title.icon.loadImage(on: titleView.imageView, targetSize: Constants.titleIconSize, animated: true)
    }

    func didReceive(viewModel: SubtensorSubnetDetailsViewModel) {
        rootView.priceWidget.bind(viewModel: viewModel.priceWidget)
        rootView.validatorView.bind(viewModel: viewModel.validator)
        rootView.estimateView.bind(viewModel: viewModel.estimate)
        rootView.bind(factorsHeading: viewModel.factors.heading)
        rootView.factorsView.bind(viewModel: viewModel.factors)
        rootView.moreDetailsView.numberCell.detailsLabel.text = viewModel.subnetNumber

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

    func priceChartView(_: SubtensorSubnetPriceChartView, didSelectPointAt index: Int) {
        seekHapticPlayer.play()
        presenter.selectChartPoint(at: index)
    }

    func priceChartViewDidEndSelection(_: SubtensorSubnetPriceChartView) {
        seekHapticPlayer.reset()
        presenter.selectChartPoint(at: nil)
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
