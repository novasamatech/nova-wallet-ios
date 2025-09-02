import UIKit
import Foundation_iOS

final class OperationDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = OperationDetailsViewLayout

    let presenter: OperationDetailsPresenterProtocol
    let localizationManager: LocalizationManagerProtocol

    var selectedLocale: Locale { localizationManager.selectedLocale }

    init(
        presenter: OperationDetailsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.localizationManager = localizationManager

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = OperationDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()

        presenter.setup()
    }

    private func setup() {
        navigationItem.titleView = rootView.timeLabel
    }

    private func applyTime(from viewModel: OperationDetailsViewModel) {
        rootView.timeLabel.text = viewModel.time
        rootView.timeLabel.sizeToFit()
    }

    private func applyIcon(from viewModel: OperationDetailsViewModel) {
        let settings = ImageViewModelSettings(
            targetSize: OperationDetailsViewLayout.Constants.imageSize,
            cornerRadius: nil,
            tintColor: R.color.colorIconSecondary()
        )

        rootView.iconView.bind(viewModel: viewModel.iconViewModel, settings: settings)
    }

    private func applyAmount(from viewModel: OperationDetailsViewModel) {
        switch viewModel.status {
        case .completed:
            rootView.amountLabel.textColor = R.color.colorTextPrimary()
        case .pending, .failed:
            rootView.amountLabel.textColor = R.color.colorTextSecondary()
        }

        rootView.amountLabel.text = viewModel.amount?.amount
        rootView.priceLabel.text = viewModel.amount?.price
    }

    private func applyStatus(from viewModel: OperationDetailsViewModel) {
        let detailsLabel = rootView.statusView.detailsLabel
        let iconView = rootView.statusView.imageView

        switch viewModel.status {
        case .completed:
            detailsLabel.textColor = R.color.colorTextPositive()
            detailsLabel.text = R.string.localizable.transactionStatusCompleted(
                preferredLanguages: selectedLocale.rLanguages
            ).uppercased()
            iconView.image = R.image.iconAlgoItem()
        case .pending:
            detailsLabel.textColor = R.color.colorTextSecondary()
            detailsLabel.text = R.string.localizable.transactionStatusPending(
                preferredLanguages: selectedLocale.rLanguages
            ).uppercased()
            iconView.image = R.image.iconPending()?.withRenderingMode(.alwaysTemplate)
                .tinted(with: R.color.colorIconSecondary()!)
        case .failed:
            detailsLabel.textColor = R.color.colorTextNegative()
            detailsLabel.text = R.string.localizable.transactionStatusFailed(
                preferredLanguages: selectedLocale.rLanguages
            ).uppercased()
            iconView.image = R.image.iconErrorFilled()
        }
    }

    private func applyTransfer(
        viewModel: OperationTransferViewModel,
        networkViewModel: NetworkViewModel
    ) {
        let transferView: OperationDetailsTransferView = rootView.setupLocalizableView()
        transferView.locale = selectedLocale
        transferView.bind(viewModel: viewModel, networkViewModel: networkViewModel)

        let sendButton = rootView.setupActionButton()
        sendButton.imageWithTitleView?.title = R.string.localizable.txDetailsSendTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        transferView.senderView.addTarget(
            self,
            action: #selector(actionSender),
            for: .touchUpInside
        )

        transferView.recepientView.addTarget(
            self,
            action: #selector(actionRecepient),
            for: .touchUpInside
        )

        transferView.transactionHashView.addTarget(
            self,
            action: #selector(actionOperationId),
            for: .touchUpInside
        )

        sendButton.addTarget(
            self,
            action: #selector(actionRepeatOperation),
            for: .touchUpInside
        )
    }

    private func applyExtrinsic(
        viewModel: OperationExtrinsicViewModel,
        networkViewModel: NetworkViewModel
    ) {
        let extrinsicView: OperationDetailsExtrinsicView = rootView.setupLocalizableView()
        extrinsicView.locale = selectedLocale
        extrinsicView.bind(viewModel: viewModel, networkViewModel: networkViewModel)

        rootView.removeActionButton()

        extrinsicView.senderView.addTarget(
            self,
            action: #selector(actionSender),
            for: .touchUpInside
        )

        extrinsicView.transactionHashView.addTarget(
            self,
            action: #selector(actionOperationId),
            for: .touchUpInside
        )
    }

    private func applyReward(
        viewModel: OperationRewardOrSlashViewModel,
        networkViewModel: NetworkViewModel
    ) {
        let rewardView: OperationDetailsRewardView = rootView.setupLocalizableView()
        rewardView.locale = selectedLocale
        rewardView.bindReward(viewModel: viewModel, networkViewModel: networkViewModel)

        rootView.removeActionButton()

        rewardView.validatorView?.addTarget(
            self,
            action: #selector(actionSender),
            for: .touchUpInside
        )

        rewardView.eventIdView.addTarget(
            self,
            action: #selector(actionOperationId),
            for: .touchUpInside
        )
    }

    private func applySlash(
        viewModel: OperationRewardOrSlashViewModel,
        networkViewModel: NetworkViewModel
    ) {
        let rewardView: OperationDetailsRewardView = rootView.setupLocalizableView()
        rewardView.locale = selectedLocale
        rewardView.bindSlash(viewModel: viewModel, networkViewModel: networkViewModel)

        rootView.removeActionButton()

        rewardView.validatorView?.addTarget(
            self,
            action: #selector(actionSender),
            for: .touchUpInside
        )

        rewardView.eventIdView.addTarget(
            self,
            action: #selector(actionOperationId),
            for: .touchUpInside
        )
    }

    func applyContract(viewModel: OperationContractCallViewModel, networkViewModel: NetworkViewModel) {
        let contentView: OperationDetailsContractView = rootView.setupLocalizableView()
        contentView.locale = selectedLocale
        contentView.bind(viewModel: viewModel, networkViewModel: networkViewModel)

        rootView.removeActionButton()

        contentView.senderView.addTarget(
            self,
            action: #selector(actionSender),
            for: .touchUpInside
        )

        contentView.contractView.addTarget(
            self,
            action: #selector(actionRecepient),
            for: .touchUpInside
        )

        contentView.transactionHashView.addTarget(
            self,
            action: #selector(actionOperationId),
            for: .touchUpInside
        )
    }

    private func applyPoolReward(
        viewModel: OperationPoolRewardOrSlashViewModel,
        networkViewModel: NetworkViewModel
    ) {
        let rewardView = applyCommonPoolRewardOrSlash()
        rewardView.bindReward(viewModel: viewModel, networkViewModel: networkViewModel)
    }

    private func applyPoolSlash(
        viewModel: OperationPoolRewardOrSlashViewModel,
        networkViewModel: NetworkViewModel
    ) {
        let slashView = applyCommonPoolRewardOrSlash()
        slashView.bindSlash(viewModel: viewModel, networkViewModel: networkViewModel)
    }

    private func applyCommonPoolRewardOrSlash() -> OperationDetailsPoolRewardView {
        let view: OperationDetailsPoolRewardView = rootView.setupLocalizableView()
        view.locale = selectedLocale

        rootView.removeActionButton()

        view.poolView.addTarget(
            self,
            action: #selector(actionSender),
            for: .touchUpInside
        )

        view.eventIdView.addTarget(
            self,
            action: #selector(actionOperationId),
            for: .touchUpInside
        )

        return view
    }

    private func applySwap(
        viewModel: OperationSwapViewModel
    ) {
        let swapView: OperationDetailsSwapView = rootView.setupLocalizableView()
        swapView.locale = selectedLocale
        swapView.bind(viewModel: viewModel)

        let repeatOperationButton = rootView.setupActionButton()
        repeatOperationButton.imageWithTitleView?.title = R.string.localizable.commonActionRepeatOperation(
            preferredLanguages: selectedLocale.rLanguages
        )
        swapView.rateCell.addTarget(
            self,
            action: #selector(actionRate),
            for: .touchUpInside
        )
        swapView.networkFeeCell.addTarget(
            self,
            action: #selector(actionNetworkFee),
            for: .touchUpInside
        )
        swapView.accountCell.addTarget(
            self,
            action: #selector(actionSender),
            for: .touchUpInside
        )
        swapView.transactionHashView.addTarget(
            self,
            action: #selector(actionOperationId),
            for: .touchUpInside
        )
        repeatOperationButton.addTarget(
            self,
            action: #selector(actionRepeatOperation),
            for: .touchUpInside
        )
    }

    @objc func actionSender() {
        presenter.showSenderActions()
    }

    @objc func actionOperationId() {
        presenter.showOperationActions()
    }

    @objc func actionRecepient() {
        presenter.showRecepientActions()
    }

    @objc func actionRepeatOperation() {
        presenter.repeatOperation()
    }

    @objc func actionRate() {
        presenter.showRateInfo()
    }

    @objc func actionNetworkFee() {
        presenter.showNetworkFeeInfo()
    }
}

extension OperationDetailsViewController: OperationDetailsViewProtocol {
    func didReceive(viewModel: OperationDetailsViewModel) {
        applyTime(from: viewModel)
        applyIcon(from: viewModel)
        applyAmount(from: viewModel)
        applyStatus(from: viewModel)

        let networkViewModel = viewModel.networkViewModel

        switch viewModel.content {
        case let .transfer(transferViewModel):
            applyTransfer(viewModel: transferViewModel, networkViewModel: networkViewModel)
        case let .extrinsic(extrinsicViewModel):
            applyExtrinsic(viewModel: extrinsicViewModel, networkViewModel: networkViewModel)
        case let .reward(rewardViewModel):
            applyReward(viewModel: rewardViewModel, networkViewModel: networkViewModel)
        case let .slash(slashViewModel):
            applySlash(viewModel: slashViewModel, networkViewModel: networkViewModel)
        case let .contract(contractViewModel):
            applyContract(viewModel: contractViewModel, networkViewModel: networkViewModel)
        case let .poolReward(poolRewardViewModel):
            applyPoolReward(viewModel: poolRewardViewModel, networkViewModel: networkViewModel)
        case let .poolSlash(poolSlashViewModel):
            applyPoolSlash(viewModel: poolSlashViewModel, networkViewModel: networkViewModel)
        case let .swap(swapViewModel):
            applySwap(viewModel: swapViewModel)
        }
    }
}
