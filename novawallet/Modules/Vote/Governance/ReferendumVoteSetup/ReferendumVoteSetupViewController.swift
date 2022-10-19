import UIKit
import SoraFoundation

final class ReferendumVoteSetupViewController: UIViewController {
    typealias RootViewType = ReferendumVoteSetupViewLayout

    let presenter: ReferendumVoteSetupPresenterProtocol

    init(
        presenter: ReferendumVoteSetupPresenterProtocol,
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
        view = ReferendumVoteSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }

    private func setupLocalization() {

    }
}

extension ReferendumVoteSetupViewController: ReferendumVoteSetupViewProtocol {}

extension ReferendumVoteSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
