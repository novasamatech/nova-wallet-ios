import Foundation
import SoraFoundation
import UIKit

struct MessageSheetViewModel<IType, CType> {
    let title: LocalizableResource<String>
    let message: LocalizableResource<String>
    let graphics: IType?
    let content: CType?
    let hasAction: Bool
}
