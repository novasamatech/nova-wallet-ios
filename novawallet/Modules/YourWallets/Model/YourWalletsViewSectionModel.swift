struct YourWalletsViewSectionModel: SectionProtocol, Hashable {
    let header: HeaderModel?
    var cells: [YourWalletsViewModelCell]

    struct HeaderModel: Hashable {
        let title: String
        let icon: UIImage?
    }
}

enum YourWalletsViewModelCell: Hashable {
    case common(CommonModel)
    case notFound(NotFoundModel)
    
    struct NotFoundModel {
        let name: String?
        let warning: String
        let imageViewModel: DrawableIconViewModel?
    }

    struct CommonModel {
        let displayAddress: DisplayAddress
        let imageViewModel: DrawableIconViewModel?
        let chainIcon: DrawableIconViewModel?
        var isSelected: Bool
    }
}

// MARK: - Hashable

extension YourWalletsViewModelCell.NotFoundModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(name ?? "")
        hasher.combine(warning)
    }

    static func == (lhs: YourWalletsViewModelCell.NotFoundModel,
                    rhs: YourWalletsViewModelCell.NotFoundModel) -> Bool {
        rhs.name == lhs.name && rhs.warning == lhs.warning
    }
}

extension YourWalletsViewModelCell.CommonModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(displayAddress.address)
        hasher.combine(displayAddress.username)
        hasher.combine(isSelected)
    }
    
    static func == (lhs: YourWalletsViewModelCell.CommonModel,
                    rhs: YourWalletsViewModelCell.CommonModel) -> Bool {
        lhs.displayAddress.address == rhs.displayAddress.address &&
        lhs.displayAddress.username == rhs.displayAddress.username &&
        lhs.isSelected == rhs.isSelected
    }
}
