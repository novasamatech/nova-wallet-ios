import UIKit

final class ParaStkCollatorInfoViewController: UIViewController {
    typealias RootViewType = ParaStkCollatorInfoViewLayout

    let presenter: ParaStkCollatorInfoPresenterProtocol

    init(presenter: ParaStkCollatorInfoPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ParaStkCollatorInfoViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension ParaStkCollatorInfoViewController: ParaStkCollatorInfoViewProtocol {}