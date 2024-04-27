import UIKit

struct WalletImportOptionViewModel {
    enum RowItem {
        enum PrimaryImagePosition {
            case center
            case right
        }

        typealias ActionClosure = () -> Void

        struct Primary {
            let backgroundImage: UIImage
            let mainImage: UIImage
            let mainImagePosition: PrimaryImagePosition
            let title: String
            let subtitle: String
            let onAction: ActionClosure
        }

        struct Secondary {
            let image: UIImage
            let title: String
            let onAction: ActionClosure
        }

        case primary(Primary)
        case secondary(Secondary)
    }

    let rows: [[RowItem]]
}
