import Foundation
import UIKit_iOS

final class HistoryAHMTableViewCell: PlainBaseTableViewCell<HistoryAHMView> {
    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear
    }

    func bind(_ viewModel: HistoryAHMViewModel) {
        contentDisplayView.bind(viewModel)
    }
}

final class HistoryAHMView: GenericBorderedView<
    IconDetailsGenericView<GenericTitleValueView<UILabel, TriangularedButton>>
> {
    var iconView: UIImageView {
        contentView.imageView
    }

    var messageLabel: UILabel {
        contentView.detailsView.titleView
    }

    var actionButton: TriangularedButton {
        contentView.detailsView.valueView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }
}

// MARK: - Private

private extension HistoryAHMView {
    func setupLayout() {
        contentInsets = Constants.contentInsets
        contentView.spacing = Constants.iconToMessage
        contentView.detailsView.spacing = Constants.messageToAction
    }

    func setupStyle() {
        iconView.image = R.image.iconHistoryGray18()
        iconView.contentMode = .scaleAspectFit

        backgroundView.apply(style: .roundedLightCell)

        messageLabel.apply(style: .caption1Primary)
        messageLabel.numberOfLines = 0

        actionButton.applyAccessoryStyle()
        actionButton.triangularedView?.strokeColor = .clear
        actionButton.triangularedView?.highlightedStrokeColor = .clear
        actionButton.imageWithTitleView?.titleFont = .semiBoldCaption1
        actionButton.imageWithTitleView?.titleColor = R.color.colorButtonTextAccent()
    }
}

// MARK: - Internal

extension HistoryAHMView {
    func bind(_ viewModel: HistoryAHMViewModel) {
        messageLabel.text = viewModel.message
        actionButton.imageWithTitleView?.title = viewModel.buttonTitle
    }
}

// MARK: - Constants

private extension HistoryAHMView {
    enum Constants {
        static let iconToMessage: CGFloat = 12
        static let messageToAction: CGFloat = 12
        static let contentInsets = UIEdgeInsets(
            top: 10.0,
            left: 12.0,
            bottom: 10.0,
            right: 16.0
        )
    }
}
