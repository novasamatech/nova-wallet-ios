import UIKit
import Foundation_iOS

final class MultisigTxDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = MultisigTxDetailsViewLayout

    let presenter: MultisigTxDetailsPresenterProtocol

    init(presenter: MultisigTxDetailsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = MultisigTxDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension MultisigTxDetailsViewController: MultisigTxDetailsViewProtocol {
    func didReceive(viewModel: MultisigTxDetailsViewModel) {
        title = viewModel.title
        rootView.bind(viewModel: viewModel)
    }

    func didReceive(
        depositViewModel: MultisigTxDetailsViewModel.SectionField<BalanceViewModelProtocol>
    ) {
        rootView.bind(deposit: depositViewModel)
    }
}
