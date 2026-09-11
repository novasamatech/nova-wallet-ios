import Foundation
import Foundation_iOS

final class ApplicationHandlerStub: ApplicationHandlerProtocol {
    private(set) var delegateAssignments: [Bool] = []

    weak var delegate: ApplicationHandlerDelegate? {
        didSet {
            delegateAssignments.append(delegate != nil)
        }
    }

    func enterForeground() {
        delegate?.didReceiveWillEnterForeground?(notification: Notification(name: .init("test")))
    }

    func enterBackground() {
        delegate?.didReceiveDidEnterBackground?(notification: Notification(name: .init("test")))
    }
}
