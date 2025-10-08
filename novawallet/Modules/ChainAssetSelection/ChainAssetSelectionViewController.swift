import UIKit
import Rswift
import Foundation_iOS

final class ChainAssetSelectionViewController: SelectionListViewController<ChainAssetSelectionTableViewCell> {
    override var selectableCellIdentifier: ReuseIdentifier<ChainAssetSelectionTableViewCell>! {
        ReuseIdentifier(identifier: ChainAssetSelectionTableViewCell.reuseIdentifier)
    }

    let localizedTitle: LocalizableResource<String>

    let presenter: ChainAssetSelectionPresenterProtocol

    init(
        nibName: String,
        localizedTitle: LocalizableResource<String>,
        presenter: ChainAssetSelectionPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.localizedTitle = localizedTitle

        super.init(nibName: nibName, bundle: nil)

        listPresenter = presenter
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()

        presenter.setup()
    }
}

extension ChainAssetSelectionViewController: ChainAssetSelectionViewProtocol {}

extension ChainAssetSelectionViewController: Localizable {
    func applyLocalization() {
        title = localizedTitle.value(for: selectedLocale)
    }
}
