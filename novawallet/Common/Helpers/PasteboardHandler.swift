import Foundation
import UIKit

@objc protocol PasteboardHandlerDelegate {
    @objc optional func didReceivePasteboardChange(notification: Notification)
    @objc optional func didReceivePasteboardRemove(notification: Notification)
}

protocol PasteboardHandlerProtocol: AnyObject {
    var delegate: PasteboardHandlerDelegate? { get set }
    var pasteboard: UIPasteboard { get }
}

final class PasteboardHandler: NSObject, PasteboardHandlerProtocol {
    let pasteboard: UIPasteboard

    weak var delegate: PasteboardHandlerDelegate?

    deinit {
        clearNotificationHandling()
    }

    init(pasteboard: UIPasteboard, delegate: PasteboardHandlerDelegate? = nil) {
        self.pasteboard = pasteboard
        self.delegate = delegate
    }

    private func setupNotificationHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveChange(notification:)),
            name: UIPasteboard.changedNotification,
            object: pasteboard
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveRemove(notification:)),
            name: UIPasteboard.removedNotification,
            object: pasteboard
        )
    }

    private func clearNotificationHandling() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIPasteboard.changedNotification,
            object: pasteboard
        )

        NotificationCenter.default.removeObserver(
            self,
            name: UIPasteboard.removedNotification,
            object: pasteboard
        )
    }

    @objc private func didReceiveChange(notification: Notification) {
        delegate?.didReceivePasteboardChange?(notification: notification)
    }

    @objc private func didReceiveRemove(notification: Notification) {
        delegate?.didReceivePasteboardRemove?(notification: notification)
    }
}
