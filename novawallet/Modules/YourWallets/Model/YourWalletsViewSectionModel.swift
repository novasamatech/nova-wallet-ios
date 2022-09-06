import UIKit

struct YourWalletsViewSectionModel: SectionProtocol, Hashable {
    let header: HeaderViewModel?
    var cells: [YourWalletsCellViewModel]

    struct HeaderViewModel: Hashable {
        let title: String
        let icon: UIImage?
    }
}

enum YourWalletsCellViewModel: Hashable {
    case common(CommonModel)
    case warning(WarningModel)

    struct WarningModel {
        let metaId: String
        let accountName: String?
        let warning: String
        let imageViewModel: DrawableIconViewModel?
    }

    struct CommonModel {
        let metaId: String
        let displayAddress: DisplayAddress
        let imageViewModel: DrawableIconViewModel?
        let chainIcon: DrawableIconViewModel?
        var isSelected: Bool
    }
}

// MARK: - Hashable

extension YourWalletsCellViewModel.WarningModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(metaId)
        hasher.combine(accountName ?? "")
        hasher.combine(warning)
    }

    static func == (
        lhs: YourWalletsCellViewModel.WarningModel,
        rhs: YourWalletsCellViewModel.WarningModel
    ) -> Bool {
        rhs.metaId == lhs.metaId &&
            rhs.accountName == lhs.accountName &&
            rhs.warning == lhs.warning
    }
}

extension YourWalletsCellViewModel.CommonModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(metaId)
        hasher.combine(displayAddress.address)
        hasher.combine(displayAddress.username)
        hasher.combine(isSelected)
    }

    static func == (
        lhs: YourWalletsCellViewModel.CommonModel,
        rhs: YourWalletsCellViewModel.CommonModel
    ) -> Bool {
        lhs.metaId == rhs.metaId &&
            lhs.displayAddress.address == rhs.displayAddress.address &&
            lhs.displayAddress.username == rhs.displayAddress.username &&
            lhs.isSelected == rhs.isSelected
    }
}
