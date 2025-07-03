import UIKit

final class MultisigOperationConfirmViewController: UIViewController {
    typealias RootViewType = MultisigOperationConfirmViewLayout

    let presenter: MultisigOperationConfirmPresenterProtocol

    init(presenter: MultisigOperationConfirmPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
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
    }
}

// MARK: - MultisigOperationConfirmViewProtocol

extension MultisigOperationConfirmViewController: MultisigOperationConfirmViewProtocol {
    func didReceive(viewModel: MultisigOperationConfirmViewModel) {
        print(viewModel)
    }

    func didReceive(feeViewModel: MultisigOperationConfirmViewModel.SectionField<BalanceViewModelProtocol?>) {
        print(feeViewModel)
    }
}
