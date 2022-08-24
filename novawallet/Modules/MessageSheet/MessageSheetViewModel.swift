import Foundation
import SoraFoundation
import UIKit

struct MessageSheetViewModel<T> {
    let title: LocalizableResource<String>
    let message: LocalizableResource<String>
    let graphics: T?
    let hasAction: Bool
}
