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
        rootView.validatorCell.addTarget(self, action: #selector(actionValidatorInfo), for: .touchUpInside)
        rootView.subnetValidatorCell.addTarget(self, action: #selector(actionValidatorInfo), for: .touchUpInside)
        rootView.actionButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)
    }

    func applyHeader(_ header: SubtensorUnstakeHeaderViewModel) {
        let titleView = rootView.amountTitleView

        titleView.titleLabel.text = header.title
        titleView.buttonTitle.text = header.prefix

        if let link = header.link {
            titleView.buttonTitle.apply(style: .footnoteSecondary)
            titleView.buttonValue.apply(style: .footnoteSecondary)
            titleView.buttonValue.attributedText = createLinkText(header.value ?? "", link: link)
        } else {
            titleView.buttonTitle.apply(style: .footnoteAccentText)
            titleView.buttonValue.apply(style: .footnotePrimary)
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
                .font: UIFont.regularFootnote,
                .foregroundColor: R.color.colorTextSecondary()!
            ]
        )

        let linkRange = (text as NSString).range(of: link, options: .backwards)

        if linkRange.location != NSNotFound {
            attributedText.addAttribute(.foregroundColor, value: R.color.colorButtonTextAccent()!, range: linkRange)
        }

        return attributedText
    }

    func applyBalanceRow(_ viewModel: SubtensorSetupBalanceRowViewModel, cell: StackTitleMultiValueCell) {
        switch viewModel {
        case .hidden:
            cell.isHidden = true
            cell.stopLoadingIfNeeded()
        case .loading:
            cell.isHidden = false
            cell.startLoadingIfNeeded()
        case let .value(balance):
            cell.isHidden = false
            cell.stopLoadingIfNeeded()
            cell.bind(viewModel: balance)
        }
    }

    func applyRow(_ viewModel: SubtensorSetupRowViewModel, cell: StackTitleMultiValueCell) {
        switch viewModel {
        case .hidden:
            cell.isHidden = true
            cell.stopLoadingIfNeeded()
        case .loading:
            cell.isHidden = false
            cell.startLoadingIfNeeded()
        case let .value(value):
            cell.isHidden = false
            cell.stopLoadingIfNeeded()
            cell.rowContentView.valueView.bind(topValue: value, bottomValue: nil)
        }
    }

    func applyValidator(_ viewModel: SubtensorSetupValidatorViewModel) {
        guard isRoot else {
            applySubnetValidator(viewModel)
            return
        }

        let cell = rootView.validatorCell

        if case let .selected(displayAddress, _) = viewModel {
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

        if case let .selected(displayAddress, _) = viewModel {
            cell.rowContentView.bind(viewModel: displayAddress)
        }

        rootView.setSkeleton(
            rootView.subnetValidatorSkeletonView,
            loading: viewModel.isLoading,
            hiding: cell.rowContentView.valueView
        )
    }

    func applyNetworkFee(_ viewModel: BalanceViewModelProtocol?) {
        let feeView: NetworkFeeView = rootView.networkFeeCell.rowContentView

        feeView.bind(viewModel: viewModel ?? BalanceViewModel(amount: "", price: nil))
        rootView.setSkeleton(rootView.feeSkeletonView, loading: viewModel == nil, hiding: feeView.tokenLabel)
    }

    func applyDetails(_ details: SubtensorUnstakeDetailsViewModel) {
        applyBalanceRow(details.receive, cell: rootView.receiveCell)
        applyRow(details.swapRate, cell: rootView.swapRateCell)
        applyValidator(details.validator)
        applyNetworkFee(details.networkFee)

        rootView.detailsTableView.updateLayout()
    }

    func applyNotes(_ viewModel: SubtensorUnstakeSetupViewModel) {
        rootView.noteView.isHidden = viewModel.note == nil
        rootView.noteLabel.text = viewModel.note

        rootView.feeAlertView.isHidden = viewModel.feeWarning == nil
        rootView.feeAlertView.contentView.detailsLabel.text = viewModel.feeWarning

        rootView.feeDisclosureLabel.isHidden = viewModel.feeDisclosure == nil
        rootView.feeDisclosureLabel.text = viewModel.feeDisclosure

        rootView.holdAlertView.isHidden = viewModel.holdWarning == nil
        rootView.holdAlertView.contentView.detailsLabel.text = viewModel.holdWarning

        rootView.captionLabel.isHidden = viewModel.caption == nil
        rootView.captionLabel.text = viewModel.caption
    }

    func applyAction(_ viewModel: SubtensorSetupActionViewModel) {
        if viewModel.isEnabled {
            rootView.actionButton.applyEnabledStyle()
        } else {
            rootView.actionButton.applyDisabledStyle()
        }

        rootView.actionButton.isUserInteractionEnabled = viewModel.isEnabled
        rootView.actionButton.imageWithTitleView?.title = viewModel.title
        rootView.actionButton.invalidateLayout()
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
        rootView.amountInputView.isUserInteractionEnabled = viewModel.isInputEnabled

        applyDetails(viewModel.details)
        applyNotes(viewModel)
        applyAction(viewModel.action)
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
