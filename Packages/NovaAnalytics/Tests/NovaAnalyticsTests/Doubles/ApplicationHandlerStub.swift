import Foundation
import Foundation_iOS

final class ApplicationHandlerStub: ApplicationHandlerProtocol {
    weak var delegate: ApplicationHandlerDelegate?

    func enterForeground() {
        delegate?.didReceiveWillEnterForeground?(notification: Notification(name: .init("test")))
    }
}
