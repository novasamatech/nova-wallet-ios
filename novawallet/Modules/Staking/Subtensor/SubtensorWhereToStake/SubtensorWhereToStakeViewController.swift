import UIKit
import Foundation_iOS

final class SubtensorWhereToStakeViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorWhereToStakeViewLayout
    let presenter: SubtensorWhereToStakePresenterProtocol
    private var cards: [SubtensorWhereToStakeCardModel] = []

    init(presenter: SubtensorWhereToStakePresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() { view = SubtensorWhereToStakeViewLayout() }

    override func viewDidLoad() {
        super.viewDidLoad()
        rootView.collectionView.dataSource = self
        presenter.setup()
    }
}

extension SubtensorWhereToStakeViewController: SubtensorWhereToStakeViewProtocol {
    func didReceive(cards: [SubtensorWhereToStakeCardModel], title: String, caption: String) {
        self.cards = cards
        self.title = title
        rootView.bind(pageCount: cards.count, caption: caption)
    }
}

extension SubtensorWhereToStakeViewController: UICollectionViewDataSource {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        cards.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithType(SubtensorWhereToStakeCardCell.self, for: indexPath)!
        let card = cards[indexPath.item]
        cell.view.bind(model: card)
        cell.view.focus = indexPath.item == rootView.currentPage ? 1 : 0
        cell.view.onChoose = { [weak self] in self?.presenter.choose(card.order) }
        return cell
    }
}

extension SubtensorWhereToStakeViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }
        presenter.setup()
    }
}
