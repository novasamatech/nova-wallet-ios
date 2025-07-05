import Foundation
import UIKit

struct StackCellViewModel {
    let details: String
    let imageViewModel: ImageViewModelProtocol?
    let lineBreakMode: NSLineBreakMode

    init(
        details: String,
        imageViewModel: ImageViewModelProtocol?,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail
    ) {
        self.details = details
        self.imageViewModel = imageViewModel
        self.lineBreakMode = lineBreakMode
    }
}
