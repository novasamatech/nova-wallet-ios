import Foundation

struct DAppBrowserTabViewModel {
    let uuid: UUID
    let stateRender: ImageViewModelProtocol?
    let name: String
    let icon: ImageViewModelProtocol?
    let onClose: (UUID) -> Void
}
