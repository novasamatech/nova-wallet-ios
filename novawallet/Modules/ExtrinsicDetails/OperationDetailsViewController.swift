import UIKit
import SoraFoundation

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
        rootView.iconView.bind(
            viewModel: viewModel.iconViewModel,
            size: OperationDetailsViewLayout.Constants.imageSize
        )
    }

    private func applyAmount(from viewModel: OperationDetailsViewModel) {
        switch viewModel.status {
        case .completed:
            rootView.amountLabel.textColor = R.color.colorWhite()
        case .pending, .failed:
            rootView.amountLabel.textColor = R.color.colorTransparentText()
        }

        rootView.amountLabel.text = viewModel.amount
    }

    private func applyStatus(from viewModel: OperationDetailsViewModel) {
        let detailsLabel = rootView.statusView.detailsLabel
        let iconView = rootView.statusView.imageView

        switch viewModel.status {
        case .completed:
            detailsLabel.textColor = R.color.colorGreen()
            detailsLabel.text = R.string.localizable.transactionStatusCompleted(
                preferredLanguages: selectedLocale.rLanguages
            ).uppercased()
            iconView.image = R.image.iconAlgoItem()
        case .pending:
            detailsLabel.textColor = R.color.colorTransparentText()
            detailsLabel.text = R.string.localizable.transactionStatusPending(
                preferredLanguages: selectedLocale.rLanguages
            ).uppercased()
            iconView.image = R.image.iconPending()?.withRenderingMode(.alwaysTemplate)
                .tinted(with: R.color.colorTransparentText()!)
        case .failed:
            detailsLabel.textColor = R.color.colorRed()
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
        let transferView = rootView.setupTransferView()
        transferView.locale = selectedLocale
        transferView.bind(viewModel: viewModel, networkViewModel: networkViewModel)
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
            break
        case let .reward(rewardViewModel):
            break
        case let .slash(slashViewModel):
            break
        }
    }
}
