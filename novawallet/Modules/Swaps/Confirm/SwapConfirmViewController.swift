import UIKit
import SoraFoundation

final class SwapConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapConfirmViewLayout

    let presenter: SwapConfirmPresenterProtocol

    init(presenter: SwapConfirmPresenterProtocol,
         localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwapConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        presenter.setup()
    }
    
    private func setupLocalization() {
        rootView.setup(locale: selectedLocale)
    }
    
    private func setupHandlers() {
       
    }
}

extension SwapConfirmViewController: SwapConfirmViewProtocol {}

extension SwapConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
