import Foundation
import SoraUI
import UIKit

final class StakingTypeView: RowView<GenericTitleValueView<MultiValueView, UIImageView>> {
    var titleLabel: UILabel { rowContentView.titleView.valueTop }

    var subtitleLabel: UILabel { rowContentView.titleView.valueBottom }

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.apply(style: .footnotePrimary)
        subtitleLabel.apply(style: .init(
            textColor: R.color.colorTextPositive(),
            font: .caption1
        ))

        rowContentView.valueView.image = R.image.iconChevronRight()
        roundedBackgroundView.apply(style: .roundedLightCell)
        preferredHeight = 52
        contentInsets = .init(top: 9, left: 16, bottom: 9, right: 16)
        borderView.borderType = .none
    }

    func bind(viewModel: LoadableViewModelState<MultiValueView.Model>) {
        switch viewModel {
        case .loading:
            // TODO:
            break
        case let .cached(value), let .loaded(value):
            rowContentView.titleView.bind(viewModel: value)
        }
    }
}
