import UIKit
import Foundation_iOS

final class MultisigOperationConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = MultisigOperationConfirmViewLayout

    let presenter: MultisigOperationConfirmPresenterProtocol

    init(
        presenter: MultisigOperationConfirmPresenterProtocol,
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
        view = MultisigOperationConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        setupLocalization()
    }
}

// MARK: - Private

private extension MultisigOperationConfirmViewController {
    func setupLocalization() {
        rootView.signatoryListView.set(locale: selectedLocale)
    }
}

// MARK: - MultisigOperationConfirmViewProtocol

extension MultisigOperationConfirmViewController: MultisigOperationConfirmViewProtocol {
    func didReceive(viewModel: MultisigOperationConfirmViewModel) {
        title = viewModel.title

        rootView.bind(viewModel: viewModel)
    }

    func didReceive(feeViewModel: MultisigOperationConfirmViewModel.SectionField<BalanceViewModelProtocol?>) {
        print(feeViewModel)
    }
}

// MARK: - Localizable

extension MultisigOperationConfirmViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}
