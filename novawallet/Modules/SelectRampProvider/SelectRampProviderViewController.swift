import UIKit

final class SelectRampProviderViewController: UIViewController, ViewHolder {
    typealias RootViewType = SelectRampProviderViewLayout

    let presenter: SelectRampProviderPresenterProtocol

    init(presenter: SelectRampProviderPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SelectRampProviderViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

// MARK: SelectRampProviderViewProtocol

extension SelectRampProviderViewController: SelectRampProviderViewProtocol {
    func didReceive(_ viewModel: SelectRampProvider.ViewModel) {
        
    }
}
