import UIKit
import SoraFoundation

final class MoonbeamTermsViewController: UIViewController, ViewHolder {
    typealias RootViewType = MoonbeamTermsViewLayout

    let presenter: MoonbeamTermsPresenterProtocol

    init(presenter: MoonbeamTermsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = MoonbeamTermsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.descriptionLabel.text = "You need to submit agreement with Terms & Conditions on the blockchain to proceed"
        rootView.termsLabel.text = "I have read and agree to Terms & Conditions"
        title = "Terms & Conditions"
        presenter.setup()
    }
}

extension MoonbeamTermsViewController: MoonbeamTermsViewProtocol {
    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.bind(feeViewModel: viewModel)
    }
}
