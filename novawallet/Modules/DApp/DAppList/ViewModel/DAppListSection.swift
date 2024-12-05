import Foundation

enum DAppListSectionViewModel {
    case header(DAppListSection)
    case categorySelect(DAppListSection)
    case favorites(DAppListSection)
    case category(DAppListSection)

    var model: DAppListSection {
        switch self {
        case let .category(model),
             let .favorites(model),
             let .header(model),
             let .categorySelect(model):
            return model
        }
    }
}

struct DAppListSection: Hashable, SectionProtocol {
    let title: String?
    var cells: [DAppListItem]
}

enum DAppListItem: Hashable {
    case header(WalletSwitchViewModel)
    case categorySelect([DAppCategoryViewModel])
    case favorites(model: DAppViewModel, categoryName: String)
    case category(model: DAppViewModel, categoryName: String)

    func hash(into hasher: inout Hasher) {
        switch self {
        case let .category(model, categoryName), let .favorites(model, categoryName):
            hasher.combine(model)
            hasher.combine(categoryName)
        case let .header(model):
            hasher.combine(model)
        case let .categorySelect(models):
            hasher.combine(models)
        }
    }

    static func == (lhs: DAppListItem, rhs: DAppListItem) -> Bool {
        switch (lhs, rhs) {
        case let (.category(lhsModel, lhsCategoryName), .category(rhsModel, rhsCategoryName)):
            lhsModel == rhsModel && lhsCategoryName == rhsCategoryName
        case let (.favorites(lhsModel, lhsCategoryName), .favorites(rhsModel, rhsCategoryName)):
            lhsModel == rhsModel && lhsCategoryName == rhsCategoryName
        case let (.header(lhsModel), .header(rhsModel)):
            lhsModel == rhsModel
        case let (.categorySelect(lhsModel), .categorySelect(rhsModel)):
            lhsModel == rhsModel
        default:
            false
        }
    }
}

extension Array where Element == DAppListSectionViewModel {
    var models: [DAppListSection] {
        map(\.model)
    }
}
