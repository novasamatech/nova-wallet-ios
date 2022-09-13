import UIKit

final class ParaStkYieldBoostScheduleConfirmViewController: UIViewController {
    typealias RootViewType = ParaStkYieldBoostScheduleConfirmViewLayout

    let presenter: ParaStkYieldBoostScheduleConfirmPresenterProtocol

    init(presenter: ParaStkYieldBoostScheduleConfirmPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ParaStkYieldBoostScheduleConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension ParaStkYieldBoostScheduleConfirmViewController: ParaStkYieldBoostScheduleConfirmViewProtocol {}
