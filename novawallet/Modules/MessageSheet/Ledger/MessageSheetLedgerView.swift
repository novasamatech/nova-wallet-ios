import UIKit

final class MessageSheetLedgerView: UIImageView, MessageSheetGraphicsProtocol {
    typealias GraphicsViewModel = MessageSheetLedgerViewModel

    private lazy var detailsView: IconDetailsView = .create { view in
        view.mode = .iconDetails
        view.stackView.axis = .vertical
        view.stackView.alignment = .center
        view.detailsLabel.textColor = R.color.colorTransparentText()
        view.detailsLabel.font = .semiBoldCaps1
        view.detailsLabel.textAlignment = .center
        view.detailsLabel.numberOfLines = 0
        view.spacing = 0.0
    }

    func bind(messageSheetGraphics: GraphicsViewModel?, locale: Locale) {
        guard let messageSheetGraphics = messageSheetGraphics else {
            return
        }

        image = messageSheetGraphics.backgroundImage

        if detailsView.superview == nil {
            addSubview(detailsView)
        }

        detailsView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(snp.bottom).offset(-messageSheetGraphics.infoRenderSize.height / 2.0)
            make.width.equalTo(messageSheetGraphics.infoRenderSize.width)
        }

        detailsView.imageView.image = messageSheetGraphics.icon
        detailsView.detailsLabel.text = messageSheetGraphics.text.value(for: locale)
    }
}
