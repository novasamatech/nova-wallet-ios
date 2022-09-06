import UIKit

final class MessageSheetImageView: UIImageView, MessageSheetGraphicsProtocol {
    typealias GraphicsViewModel = UIImage

    func bind(messageSheetGraphics: GraphicsViewModel?, locale _: Locale) {
        image = messageSheetGraphics
    }
}
