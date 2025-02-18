import Foundation

enum DAppListViewState: Equatable {
    case error
    case result([DAppListSectionViewModel])
}

enum DAppListSectionViewModel: Equatable {
    case header(DAppListSection)
    case categorySelect(DAppListSection)
    case banners(DAppListSection)
    case favorites(DAppListSection)
    case category(DAppListSection)
    case notLoaded(DAppListSection)
    case error(DAppListSection)

    var model: DAppListSection {
        switch self {
        case let .category(model),
             let .favorites(model),
             let .header(model),
             let .categorySelect(model),
             let .banners(model),
             let .notLoaded(model),
             let .error(model):
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
    case banner
    case favorites(model: DAppViewModel, categoryName: String)
    case category(model: DAppViewModel, categoryName: String)
    case notLoaded
    case error

    func hash(into hasher: inout Hasher) {
        switch self {
        case let .category(model, categoryName), let .favorites(model, categoryName):
            hasher.combine(model)
            hasher.combine(categoryName)
        case let .header(model):
            hasher.combine(model)
        case let .categorySelect(models):
            hasher.combine(models)
        default:
            break
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
        case (.notLoaded, .notLoaded):
            true
        case (.error, .error):
            true
        default:
            false
        }
    }
}

extension Array where Element == DAppListSectionViewModel {
    var models: [DAppListSection] {
        map(\.model)
    }

    var loaded: Bool {
        !contains(where: { $0.model.cells.contains(.notLoaded) })
    }
}
