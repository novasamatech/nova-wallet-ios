import Foundation

struct DAppBrowserTabViewModel {
    let uuid: UUID
    let stateRender: ImageViewModelProtocol?
    let name: String
    let icon: ImageViewModelProtocol?
    let renderModifiedAt: Date?
}

extension DAppBrowserTabViewModel: Hashable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.uuid == rhs.uuid
            && lhs.renderModifiedAt == rhs.renderModifiedAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
        hasher.combine(renderModifiedAt)
    }
}
