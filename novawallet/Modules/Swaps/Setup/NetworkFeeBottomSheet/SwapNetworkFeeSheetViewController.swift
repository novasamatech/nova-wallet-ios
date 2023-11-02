import UIKit
import SoraFoundation
import SoraUI

final class SwapNetworkFeeSheetViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapNetworkFeeSheetLayout

    let presenter: MessageSheetPresenterProtocol
    let viewModel: SwapNetworkFeeSheetViewModel

    init(
        presenter: MessageSheetPresenterProtocol,
        viewModel: SwapNetworkFeeSheetViewModel,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwapNetworkFeeSheetLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()
        setupSwitch()
    }

    private func setupLocalization() {
        rootView.titleLabel.text = viewModel.title.value(for: selectedLocale)
        rootView.detailsLabel.text = viewModel.message.value(for: selectedLocale)
        rootView.hint.detailsLabel.text = viewModel.hint.value(for: selectedLocale)
        rootView.feeTypeSwitch.titles = (0 ..< viewModel.count).map { viewModel.sectionTitle($0).value(for: selectedLocale) }
    }

    private func setupSwitch() {
        rootView.feeTypeSwitch.selectedSegmentIndex = viewModel.selectedIndex
    }

    private func setupHandlers() {
        rootView.feeTypeSwitch.addTarget(self, action: #selector(switchAction), for: .valueChanged)
    }

    @objc private func switchAction() {
        viewModel.action(rootView.feeTypeSwitch.selectedSegmentIndex)
    }
}

extension SwapNetworkFeeSheetViewController: MessageSheetViewProtocol {}

extension SwapNetworkFeeSheetViewController: ModalPresenterDelegate {
    func presenterShouldHide(_: ModalPresenterProtocol) -> Bool {
        true
    }
}

extension SwapNetworkFeeSheetViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
