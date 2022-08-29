import UIKit
import SoraFoundation
import SoraUI
import SubstrateSdk

final class YourWalletsViewController: UIViewController, ViewHolder {
    typealias RootViewType = YourWalletsViewLayout
   
    let presenter: YourWalletsPresenterProtocol
 
    init(presenter: YourWalletsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = YourWalletsViewLayout()
    }

}

// MARK: - YourWalletsViewProtocol

extension YourWalletsViewController: YourWalletsViewProtocol {
    func update(viewModel: [YourWalletsViewSectionModel]) {
    }

    func update(header: String) {
    }
}

// MARK: - UICollectionViewDelegate

extension YourWalletsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    }
}
