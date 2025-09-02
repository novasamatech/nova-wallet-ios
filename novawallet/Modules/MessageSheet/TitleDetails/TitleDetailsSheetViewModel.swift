import Foundation
import Foundation_iOS
import UIKit

struct TitleDetailsSheetViewModel {
    let title: LocalizableResource<String>
    let message: LocalizableResource<String>
    let mainAction: MessageSheetAction?
    let secondaryAction: MessageSheetAction?
}
