import UIKit
import CommonWallet
import SoraFoundation
import SoraUI

protocol RewardEstimationViewDelegate: AnyObject {
    func rewardEstimationView(_ view: RewardEstimationView, didChange amount: Decimal?) // TODO: Remove
    func rewardEstimationView(_ view: RewardEstimationView, didSelect percentage: Float) // TODO: Remove
    func rewardEstimationDidStartAction(_ view: RewardEstimationView) // TODO: What is it?
    func rewardEstimationDidRequestInfo(_ view: RewardEstimationView) // TODO: What is it?
}

final class RewardEstimationView: LocalizableView {
    @IBOutlet var backgroundView: TriangularedBlurView!

    @IBOutlet var averageAPYTitleLabel: UILabel!
    @IBOutlet var averageAPYValueLabel: UILabel!

    @IBOutlet var maximumAPYTitleLabel: UILabel!
    @IBOutlet var maximumAPYValueLabel: UILabel!

    @IBOutlet var estimateWidgetTitleLabel: UILabel!

    @IBOutlet private var actionButton: TriangularedButton!

    private var skeletonView: SkrullableView?

    var amountFormatterFactory: AssetBalanceFormatterFactoryProtocol?

    var actionTitle: LocalizableResource<String> = LocalizableResource { locale in
        R.string.localizable.stakingStartTitle(preferredLanguages: locale.rLanguages)
    } {
        didSet {
            applyActionTitle()
        }
    }

    weak var delegate: RewardEstimationViewDelegate?

    var uiFactory: UIFactoryProtocol? // TODO: Remove

    var locale = Locale.current {
        didSet {
            applyLocalization()

            if widgetViewModel != nil {
                applyWidgetViewModel()
            }
        }
    }

    private var inputViewModel: AmountInputViewModelProtocol? // TODO: Remove
    private var widgetViewModel: StakingEstimationViewModel?

    override func awakeFromNib() {
        super.awakeFromNib()

        applyLocalization()
    }

    func bind(viewModel: StakingEstimationViewModel) {
        widgetViewModel = viewModel
        applyWidgetViewModel()
    }

    private func applyWidgetViewModel() {
        if let viewModel = widgetViewModel?.assetBalance.value(for: locale) {
            estimateWidgetTitleLabel.text = R.string.localizable
                .stakingEstimateEarningTitle_v190(
                    viewModel.symbol,
                    preferredLanguages: locale.rLanguages
                )
        }

        if let viewModel = widgetViewModel?.rewardViewModel?.value(for: locale) {
            stopLoadingIfNeeded()

            averageAPYTitleLabel.text = R.string.localizable
                .stakingRewardInfoAvg(preferredLanguages: locale.rLanguages)

            maximumAPYTitleLabel.text = R.string.localizable
                .stakingRewardInfoMax(preferredLanguages: locale.rLanguages)

            averageAPYValueLabel.text = viewModel.avgAPY.apy
            maximumAPYValueLabel.text = viewModel.maxAPY.apy
        } else {
            startLoadingIfNeeded()
        }
    }

    private func applyLocalization() {
        let languages = locale.rLanguages

        estimateWidgetTitleLabel.text = R.string.localizable.stakingEstimateEarningTitle_v190(
            "",
            preferredLanguages: languages
        )

        applyActionTitle()
    }

    private func applyActionTitle() {
        let title = actionTitle.value(for: locale)
        actionButton.imageWithTitleView?.title = title
        actionButton.invalidateLayout()
    }

    func startLoadingIfNeeded() {
        guard skeletonView == nil else {
            return
        }

        averageAPYValueLabel.alpha = 0.0
        maximumAPYValueLabel.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        averageAPYValueLabel.alpha = 1.0
        maximumAPYValueLabel.alpha = 1.0
    }

    private func setupSkeleton() {
        let spaceSize = frame.size

        let skeletonView = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: createSkeletons(for: spaceSize)
        )
        .fillSkeletonStart(R.color.colorSkeletonStart()!)
        .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
        .build()

        skeletonView.frame = CGRect(origin: .zero, size: spaceSize)
        skeletonView.autoresizingMask = []
        insertSubview(skeletonView, aboveSubview: backgroundView)

        self.skeletonView = skeletonView

        skeletonView.startSkrulling()
    }

    // TODO: Change
    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let bigRowSize = CGSize(width: 72.0, height: 12.0)
        let smallRowSize = CGSize(width: 57.0, height: 6.0)

        return [
            SingleSkeleton.createRow(
                inPlaceOf: averageAPYValueLabel,
                containerView: self,
                spaceSize: spaceSize,
                size: bigRowSize
            ),

            SingleSkeleton.createRow(
                inPlaceOf: maximumAPYValueLabel,
                containerView: self,
                spaceSize: spaceSize,
                size: bigRowSize
            )
        ]
    }

    @IBAction private func actionTouchUpInside() {
        delegate?.rewardEstimationDidStartAction(self)
    }
}

extension RewardEstimationView: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
        skeletonView?.stopSkrulling()
        skeletonView?.startSkrulling()
    }

    func didUpdateSkeletonLayout() {
        guard let skeletonView = skeletonView else {
            return
        }

        if skeletonView.frame.size != frame.size {
            skeletonView.removeFromSuperview()
            self.skeletonView = nil
            setupSkeleton()
        }
    }
}
