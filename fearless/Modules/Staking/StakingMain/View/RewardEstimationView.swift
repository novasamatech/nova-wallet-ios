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

    // TODO: Remove
    @IBOutlet var amountInputView: AmountInputView!

    @IBOutlet var estimateWidgetTitleLabel: UILabel!

    // TODO: Add average title label
    @IBOutlet var monthlyTitleLabel: UILabel! // TODO: Remove
    @IBOutlet var monthlyAmountLabel: UILabel! // TODO: Remove
    @IBOutlet var monthlyFiatAmountLabel: UILabel! // TODO: Remove

    // TODO: Add max title label
    @IBOutlet var yearlyTitleLabel: UILabel! // TODO: Remove
    @IBOutlet var yearlyAmountLabel: UILabel! // TODO: Remove
    @IBOutlet var yearlyFiatAmountLabel: UILabel! // TODO: Remove

    // TODO: Remove
    @IBOutlet private var infoButton: RoundedButton!

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

    var uiFactory: UIFactoryProtocol? {
        didSet {
            setupInputAccessoryView()
        }
    }

    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyInputViewModel() // TODO: Remove

            if widgetViewModel != nil {
                applyWidgetViewModel()
            }
        }
    }

    private var inputViewModel: AmountInputViewModelProtocol? // TODO: Remove
    private var widgetViewModel: StakingEstimationViewModel?

    override func awakeFromNib() {
        super.awakeFromNib()

        amountInputView.textField.delegate = self // TODO: Remove

        applyLocalization()

        setupAmountField()
    }

    // TODO: Change
    func bind(viewModel: StakingEstimationViewModel) {
        widgetViewModel?.assetBalance.value(for: locale).iconViewModel?.cancel(
            on: amountInputView.iconView
        )

        widgetViewModel = viewModel

        if inputViewModel == nil || (inputViewModel?.decimalAmount != widgetViewModel?.amount) {
            applyInputViewModel()
        }

        applyWidgetViewModel()
    }

    // TODO: Change
    private func applyWidgetViewModel() {
        if let viewModel = widgetViewModel?.assetBalance.value(for: locale) {
            amountInputView.balanceText = R.string.localizable
                .commonAvailableFormat(
                    viewModel.balance ?? "",
                    preferredLanguages: locale.rLanguages
                )
            amountInputView.priceText = viewModel.price

            amountInputView.assetIcon = nil

            viewModel.iconViewModel?.loadAmountInputIcon(on: amountInputView.iconView, animated: true)

            amountInputView.symbol = viewModel.symbol

            estimateWidgetTitleLabel.text = R.string.localizable
                .stakingEstimateEarningTitle_v190(
                    viewModel.symbol,
                    preferredLanguages: locale.rLanguages
                )
        }

        if let viewModel = widgetViewModel?.rewardViewModel?.value(for: locale) {
            stopLoadingIfNeeded()

            infoButton.isHidden = false

            averageAPYTitleLabel.text = R.string.localizable
                .stakingRewardInfoAvg(preferredLanguages: locale.rLanguages)

            maximumAPYTitleLabel.text = R.string.localizable
                .stakingRewardInfoMax(preferredLanguages: locale.rLanguages)

            averageAPYValueLabel.text = viewModel.avgAPY.apy
            maximumAPYValueLabel.text = viewModel.maxAPY.apy
        } else {
            startLoadingIfNeeded()
            infoButton.isHidden = true
        }
    }

    // TODO: Remove
    private func applyInputViewModel() {
        guard let widgetViewModel = widgetViewModel, let amountFormatterFactory = amountFormatterFactory else {
            return
        }

        let assetInfo = widgetViewModel.assetInfo

        let formatter = amountFormatterFactory.createInputFormatter(for: assetInfo).value(for: locale)
        let newInputViewModel = AmountInputViewModel(
            symbol: assetInfo.symbol,
            amount: widgetViewModel.amount,
            limit: widgetViewModel.inputLimit,
            formatter: formatter,
            precision: Int16(formatter.maximumFractionDigits)
        )

        inputViewModel?.observable.remove(observer: self)

        inputViewModel = newInputViewModel

        amountInputView.fieldText = newInputViewModel.displayAmount
        newInputViewModel.observable.add(observer: self)
    }

    private func applyLocalization() {
        let languages = locale.rLanguages

        estimateWidgetTitleLabel.text = R.string.localizable.stakingEstimateEarningTitle_v190(
            "",
            preferredLanguages: languages
        )

        amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: languages)

        setupInputAccessoryView()
        applyActionTitle()
    }

    private func applyActionTitle() {
        let title = actionTitle.value(for: locale)
        actionButton.imageWithTitleView?.title = title
        actionButton.invalidateLayout()
    }

    // TODO: Remove
    private func setupInputAccessoryView() {
        guard let accessoryView = uiFactory?.createAmountAccessoryView(for: self, locale: locale) else {
            return
        }

        amountInputView.textField.inputAccessoryView = accessoryView
    }

    // TODO: Remove
    private func setupAmountField() {
        let textColor = R.color.colorWhite()!
        let placeholder = NSAttributedString(
            string: "0",
            attributes: [
                .foregroundColor: textColor.withAlphaComponent(0.5),
                .font: UIFont.h4Title
            ]
        )

        amountInputView.textField.attributedPlaceholder = placeholder
        amountInputView.textField.keyboardType = .decimalPad
    }

    // TODO: Change
    func startLoadingIfNeeded() {
        guard skeletonView == nil else {
            return
        }

        averageAPYValueLabel.alpha = 0.0
        maximumAPYValueLabel.alpha = 0.0
        monthlyTitleLabel.alpha = 0.0
        monthlyAmountLabel.alpha = 0.0
        monthlyFiatAmountLabel.alpha = 0.0

        yearlyTitleLabel.alpha = 0.0
        yearlyAmountLabel.alpha = 0.0
        yearlyFiatAmountLabel.alpha = 0.0

        setupSkeleton()
    }

    // TODO: Change
    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        averageAPYValueLabel.alpha = 1.0
        maximumAPYValueLabel.alpha = 1.0
        monthlyTitleLabel.alpha = 1.0
        monthlyAmountLabel.alpha = 1.0
        monthlyFiatAmountLabel.alpha = 1.0

        yearlyTitleLabel.alpha = 1.0
        yearlyAmountLabel.alpha = 1.0
        yearlyFiatAmountLabel.alpha = 1.0
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
            ),

            SingleSkeleton.createRow(
                inPlaceOf: monthlyTitleLabel,
                containerView: self,
                spaceSize: spaceSize,
                size: smallRowSize
            ),

            SingleSkeleton.createRow(
                inPlaceOf: monthlyAmountLabel,
                containerView: self,
                spaceSize: spaceSize,
                size: bigRowSize
            ),

            SingleSkeleton.createRow(
                inPlaceOf: monthlyFiatAmountLabel,
                containerView: self,
                spaceSize: spaceSize,
                size: smallRowSize
            ),

            SingleSkeleton.createRow(
                inPlaceOf: yearlyTitleLabel,
                containerView: self,
                spaceSize: spaceSize,
                size: smallRowSize
            ),

            SingleSkeleton.createRow(
                inPlaceOf: yearlyAmountLabel,
                containerView: self,
                spaceSize: spaceSize,
                size: bigRowSize
            ),

            SingleSkeleton.createRow(
                inPlaceOf: yearlyFiatAmountLabel,
                containerView: self,
                spaceSize: spaceSize,
                size: smallRowSize
            )
        ]
    }

    @IBAction private func actionTouchUpInside() {
        amountInputView.textField.resignFirstResponder()

        delegate?.rewardEstimationDidStartAction(self)
    }

    // TODO: Remove
    @IBAction private func infoTouchUpInside() {
        delegate?.rewardEstimationDidRequestInfo(self)
    }
}

// TODO: Remove
extension RewardEstimationView: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        inputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}

// TODO: Remove
extension RewardEstimationView: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        amountInputView.textField.resignFirstResponder()

        delegate?.rewardEstimationView(self, didSelect: percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        amountInputView.textField.resignFirstResponder()
    }
}

// TODO: Remove
extension RewardEstimationView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        guard let inputViewModel = inputViewModel else {
            return
        }

        amountInputView.fieldText = inputViewModel.displayAmount

        let amount = inputViewModel.decimalAmount

        delegate?.rewardEstimationView(self, didChange: amount)
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
