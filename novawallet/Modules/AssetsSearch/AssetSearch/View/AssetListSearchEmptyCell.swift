import UIKit

typealias AssetListSearchEmptyCell = CollectionViewContainerCell<EmptyCellContentView>

extension AssetListSearchEmptyCell {
    func bind(text: String) {
        view.bind(text: text)
    }
}
