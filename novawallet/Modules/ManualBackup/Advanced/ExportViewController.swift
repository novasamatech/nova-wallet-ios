import UIKit
import Foundation_iOS

final class ExportViewController: UIViewController, ViewHolder {
    typealias RootViewType = ExportViewLayout

    let presenter: ExportPresenterProtocol

    init(
        presenter: ExportPresenterProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ExportViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

// MARK: AdvancedExportViewProtocol

extension ExportViewController: ExportViewProtocol {
    func update(with viewModel: ExportViewLayout.Model) {
        rootView.bind(with: viewModel)
    }

    func updateNavbar(with viewModel: DisplayWalletViewModel) {
        let iconDetailsView: IconDetailsView = .create(with: { view in
            view.detailsLabel.apply(style: .semiboldBodyPrimary)
            view.detailsLabel.text = viewModel.name
            view.iconWidth = Constants.walletIconSize.width

            viewModel.imageViewModel?.loadImage(
                on: view.imageView,
                targetSize: Constants.walletIconSize,
                animated: true
            )
        })

        navigationItem.titleView = iconDetailsView
    }

    func updateNavbar(with text: String) {
        navigationItem.title = text
    }

    func showSecret(
        _ secret: String,
        for chainName: String
    ) {
        rootView.showSecret(
            secret,
            for: chainName
        )
    }
}

// MARK: Constants

private extension ExportViewController {
    enum Constants {
        static let walletIconSize: CGSize = .init(
            width: 28,
            height: 28
        )
    }
}
