import UIKit
import SoraFoundation

final class AcalaContributionSetupViewController: CrowdloanContributionSetupViewController {
    typealias RootViewType = AcalaContributionSetupViewLayout

    var rootView: RootViewType {
        guard let rootView = view as? RootViewType else {
            fatalError("Excpected \(RootViewType.description()) as rootView. Now \(type(of: view))")
        }
        return rootView
    }

    let presenter: AcalaContributionSetupPresenterProtocol

    init(
        presenter: AcalaContributionSetupPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(presenter: presenter, localizationManager: localizationManager)
    }

    override func loadView() {
        view = AcalaContributionSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.buttons.forEach { button in
            button.addTarget(self, action: #selector(radioButtonAction(control:)), for: .touchUpInside)
        }
        rootView.acalaLearnMoreView.addTarget(
            self,
            action: #selector(learnMoreAboutAcalaAction),
            for: .touchUpInside
        )
        rootView.bind(selectedMethod: presenter.selectedContributionMethod)
    }

    @objc
    private func radioButtonAction(control: UIControl) {
        guard let button = control as? RadioButton<AcalaContributionMethod> else { return }
        let method = button.model
        rootView.bind(selectedMethod: method)
        presenter.selectContributionMethod(method)
    }

    @objc
    private func learnMoreAboutAcalaAction() {
        presenter.handleLearnMoreAboutContributions()
    }
}
