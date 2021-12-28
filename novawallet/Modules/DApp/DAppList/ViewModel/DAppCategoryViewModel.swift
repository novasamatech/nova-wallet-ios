import Foundation

enum DAppListState {
    case loading
    case loaded(categories: [DAppCategoryViewModel])
    case error
}

struct DAppCategoryViewModel {
    let name: String
}
