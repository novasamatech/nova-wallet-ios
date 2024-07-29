import UIKit
import SoraFoundation

final class GenericLedgerAccountSelectionController: UIViewController, ViewHolder {
    typealias RootViewType = GenericLedgerAccountSelectionViewLayout

    let presenter: GenericLedgerAccountSelectionPresenterProtocol

    init(presenter: GenericLedgerAccountSelectionPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GenericLedgerAccountSelectionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        
        presenter.setup()
    }
    
    private func setupLocalization() {
        
    }
}

extension GenericLedgerAccountSelectionController: GenericLedgerAccountSelectionViewProtocol {}

extension GenericLedgerAccountSelectionController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
