import Foundation

enum ProxyUpdateStyle {
    case delegated
    case revoked

    func apply(to cell: ProxyTableViewCell) {
        switch self {
        case .delegated:
            cell.contentDisplayView.titleView.alpha = 1.0
            cell.contentDisplayView.titleLabel.textColor = R.color.colorTextPrimary()
            cell.contentDisplayView.subtitleDetailsLabel.textColor = R.color.colorTextPrimary()
            cell.contentDisplayView.subtitleDetailsImage.alpha = 1.0
        case .revoked:
            cell.contentDisplayView.titleView.alpha = 0.56
            cell.contentDisplayView.titleLabel.textColor = R.color.colorTextSecondary()
            cell.contentDisplayView.subtitleDetailsLabel.textColor = R.color.colorTextSecondary()
            cell.contentDisplayView.subtitleDetailsImage.alpha = 0.56
        }
    }
}
