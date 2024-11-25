import Foundation

struct DAppBrowserTabViewModel {
    let uuid: UUID
    let stateRender: ImageViewModelProtocol?
    let name: String
    let icon: ImageViewModelProtocol?
    let lastModified: Date
}

extension DAppBrowserTabViewModel: Hashable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.uuid == rhs.uuid
            && lhs.lastModified == rhs.lastModified
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
        hasher.combine(lastModified)
    }
}
