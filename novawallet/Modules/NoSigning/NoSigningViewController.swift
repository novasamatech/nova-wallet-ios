import UIKit

final class NoSigningViewController: UIViewController {
    typealias RootViewType = NoSigningViewLayout

    let presenter: NoSigningPresenterProtocol

    init(presenter: NoSigningPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NoSigningViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    private func setupLocalization() {
        
    }
}

extension NoSigningViewController: NoSigningViewProtocol {}
