import UIKit

final class MessageSheetImageView: UIImageView, MessageSheetGraphicsProtocol {
    typealias GraphicsViewModel = UIImage

    func bind(messageSheetGraphics: GraphicsViewModel?) {
        image = messageSheetGraphics
    }
}
