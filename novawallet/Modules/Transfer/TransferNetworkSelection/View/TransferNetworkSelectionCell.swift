import Foundation
import UIKit

typealias TransferNetworkSelectionContentView = GenericTitleValueView<
    AssetListChainView,
    GenericPairValueView<MultiValueView, RadioSelectorView>
>

final class TransferNetworkSelectionCell: PlainBaseTableViewCell<TransferNetworkSelectionContentView>,
    ModalPickerCellProtocol {
    typealias Model = TransferNetworkSelectionViewModel

    var networkView: AssetListChainView {
        contentDisplayView.titleView
    }

    var selectorView: RadioSelectorView {
        contentDisplayView.valueView.sView
    }

    var balanceView: MultiValueView {
        contentDisplayView.valueView.fView
    }

    var checkmarked: Bool {
        get {
            selectorView.selected
        }

        set {
            selectorView.selected = newValue
        }
    }

    func bind(model: Model) {
        networkView.bind(viewModel: model.network)
        balanceView.bind(topValue: model.balance?.amount ?? "", bottomValue: model.balance?.price)
    }

    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear

        contentDisplayView.valueView.setHorizontalAndSpacing(12)
        contentDisplayView.valueView.stackView.alignment = .center
    }

    override func setupLayout() {
        super.setupLayout()

        let selectorSize = 2 * selectorView.outerRadius

        selectorView.snp.makeConstraints { make in
            make.size.equalTo(selectorSize)
        }
    }
}
