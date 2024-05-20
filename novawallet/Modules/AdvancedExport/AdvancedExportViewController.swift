import UIKit

final class AdvancedExportViewController: UIViewController, ViewHolder {
    typealias RootViewType = AdvancedExportViewLayout

    let presenter: AdvancedExportPresenterProtocol

    init(presenter: AdvancedExportPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AdvancedExportViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension AdvancedExportViewController: AdvancedExportViewProtocol {
    func update(with viewModel: AdvancedExportViewLayout.Model) {
        rootView.bind(with: viewModel)
    }
}
