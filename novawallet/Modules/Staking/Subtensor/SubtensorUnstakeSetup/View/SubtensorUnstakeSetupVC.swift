import Foundation_iOS
import UIKit

final class SubtensorUnstakeSetupVC: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = SubtensorUnstakeSetupLayout

    let presenter: SubtensorUnstakeSetupPresenterProtocol
    let isRoot: Bool

    init(
        presenter: SubtensorUnstakeSetupPresenterProtocol,
        isRoot: Bool,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.isRoot = isRoot

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorUnstakeSetupLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.setupMode(isRoot: isRoot)
        setupLocalization()
        setupHandlers()

        presenter.setup()
    }
}

private extension SubtensorUnstakeSetupVC {
    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        rootView.receiveCell.titleLabel.text = strings.stakingSubtensorUiYouWillGet()
        rootView.swapRateCell.titleLabel.text = strings.stakingSubtensorUiSwapRate()
        rootView.avgBuyPriceCell.titleLabel.text = strings.stakingSubtensorUiAvgBuyPrice()
        rootView.earnedCell.titleLabel.text = strings.stakingSubtensorUiEarned()
        rootView.validatorCell.titleLabel.text = strings.stakingCommonValidator()
        rootView.subnetValidatorCell.titleButton.setTitle(strings.stakingCommonValidator())
        rootView.networkFeeCell.rowContentView.locale = selectedLocale

        setupAmountInputAccessoryView()
    }

    func setupAmountInputAccessoryView() {
        let accessoryView = UIFactory.default.createAmountAccessoryView(for: self, locale: selectedLocale)

        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    func setupHandlers() {
        rootView.amountTitleView.button.addTarget(self, action: #selector(actionMax), for: .touchUpInside)
        rootView.amountInputView.addTarget(self, action: #selector(actionAmountChange), for: .editingChanged)
        rootView.swapRateCell.addTarget(self, action: #selector(actionSwapRateInfo), for: .touchUpInside)
        rootView.avgBuyPriceCell.addTarget(self, action: #selector(actionAvgBuyPriceInfo), for: .touchUpInside)
        rootView.validatorCell.addTarget(self, action: #selector(actionValidatorInfo), for: .touchUpInside)
        rootView.subnetValidatorCell.addTarget(self, action: #selector(actionValidatorInfo), for: .touchUpInside)
        rootView.actionButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)
    }

    func applyHeader(_ header: SubtensorUnstakeHeaderViewModel) {
        let titleView = rootView.amountTitleView

        titleView.titleLabel.text = header.title
        titleView.buttonTitle.text = header.prefix

        if let link = header.link {
            titleView.buttonTitle.apply(style: .regularSubhedlineSecondary)
            titleView.buttonValue.apply(style: .regularSubhedlineSecondary)
            titleView.buttonValue.attributedText = createLinkText(header.value ?? "", link: link)
        } else {
            titleView.buttonTitle.apply(style: .regularSubhedlineAccent)
            titleView.buttonValue.apply(style: .regularSubhedlinePrimary)
            titleView.buttonValue.text = header.value
        }

        titleView.button.isUserInteractionEnabled = header.isEnabled
        titleView.button.invalidateLayout()

        rootView.setSkeleton(rootView.maxSkeletonView, loading: header.value == nil, hiding: titleView.button)
    }

    func createLinkText(_ text: String, link: String) -> NSAttributedString {
        let attributedText = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.regularSubheadline,
                .foregroundColor: R.color.colorTextSecondary()!
            ]
        )

        let linkRange = (text as NSString).range(of: link, options: .backwards)

        if linkRange.location != NSNotFound {
            attributedText.addAttribute(.foregroundColor, value: R.color.colorButtonTextAccent()!, range: linkRange)
        }

        return attributedText
    }

    func applyValidator(_ viewModel: SubtensorSetupValidatorViewModel) {
        guard isRoot else {
            applySubnetValidator(viewModel)
            return
        }

        let cell = rootView.validatorCell

        if case let .selected(displayAddress) = viewModel {
            cell.bind(
                viewModel: StackCellViewModel(
                    details: displayAddress.name ?? displayAddress.address,
                    imageViewModel: displayAddress.imageViewModel
                )
            )
        }

        rootView.setSkeleton(
            rootView.validatorSkeletonView,
            loading: viewModel.isLoading,
            hiding: cell.rowContentView.valueView
        )
    }

    func applySubnetValidator(_ viewModel: SubtensorSetupValidatorViewModel) {
        let cell = rootView.subnetValidatorCell

        if case let .selected(displayAddress) = viewModel {
            cell.rowContentView.bind(viewModel: displayAddress)
        }

        rootView.setSkeleton(
            rootView.subnetValidatorSkeletonView,
            loading: viewModel.isLoading,
            hiding: cell.rowContentView.valueView
        )
    }

    func applyDetails(_ details: SubtensorUnstakeDetailsViewModel) {
        rootView.receiveCell.apply(details.receive, bind: rootView.receiveCell.bind(viewModel:))
        rootView.swapRateCell.apply(details.swapRate)
        rootView.avgBuyPriceCell.bind(costBasisRow: details.avgBuyPrice)
        rootView.earnedCell.bind(costBasisRow: details.earned)
        applyValidator(details.validator)
        rootView.applyNetworkFee(details.networkFee)

        SubtensorDividerStyle.apply(to: rootView.detailsTableView)
    }

    func applyNotes(_ viewModel: SubtensorUnstakeSetupViewModel) {
        rootView.noteView.isHidden = viewModel.note == nil
        rootView.noteLabel.apply(text: viewModel.note ?? "", lineHeight: Constants.noteLineHeight)

        rootView.feeAlertView.isHidden = viewModel.feeWarning == nil
        rootView.feeAlertView.contentView.detailsLabel.apply(
            text: viewModel.feeWarning ?? "",
            lineHeight: Constants.alertLineHeight
        )

        rootView.holdAlertView.isHidden = viewModel.holdWarning == nil
        rootView.holdAlertView.contentView.detailsLabel.apply(
            text: viewModel.holdWarning ?? "",
            lineHeight: Constants.alertLineHeight
        )
    }

    @objc func actionMax() {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectMax()
    }

    @objc func actionAmountChange() {
        presenter.updateAmount(rootView.amountInputView.inputViewModel?.decimalAmount)
    }

    @objc func actionSwapRateInfo() {
        presenter.showSwapRateInfo()
    }

    @objc func actionAvgBuyPriceInfo() {
        presenter.showAvgBuyPriceInfo()
    }

    @objc func actionValidatorInfo() {
        presenter.showValidatorInfo()
    }

    @objc func actionProceed() {
        presenter.proceed()
    }
}

extension SubtensorUnstakeSetupVC: SubtensorUnstakeSetupViewProtocol {
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol) {
        rootView.amountInputView.bind(inputViewModel: inputViewModel)
    }

    func didReceiveAmountAsset(viewModel: AssetViewModel) {
        rootView.amountInputView.bind(assetViewModel: viewModel)
    }

    func didReceive(viewModel: SubtensorUnstakeSetupViewModel) {
        title = viewModel.title

        applyHeader(viewModel.header)

        rootView.amountInputView.bind(priceViewModel: viewModel.inputPrice)
        rootView.setAmountInputEnabled(viewModel.isInputEnabled)

        applyDetails(viewModel.details)
        applyNotes(viewModel)
        rootView.applyAction(viewModel.action)
    }

    func didStartLoading() {
        rootView.startLoading()
    }

    func didStopLoading() {
        rootView.stopLoading()
    }
}

extension SubtensorUnstakeSetupVC: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension SubtensorUnstakeSetupVC: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

private extension SubtensorUnstakeSetupVC {
    enum Constants {
        static let noteLineHeight: CGFloat = 18
        static let alertLineHeight: CGFloat = 16
    }
}
