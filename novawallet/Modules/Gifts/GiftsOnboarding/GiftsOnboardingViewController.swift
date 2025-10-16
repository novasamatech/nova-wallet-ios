import UIKit

final class GiftsOnboardingViewController: UIViewController {
    typealias RootViewType = GiftsOnboardingViewLayout

    let presenter: GiftsOnboardingPresenterProtocol

    init(presenter: GiftsOnboardingPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GiftsOnboardingViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension GiftsOnboardingViewController: GiftsOnboardingViewProtocol {}