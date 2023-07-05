import UIKit

protocol KeyboardAppearanceStrategyProtocol {
    func onViewWillAppear(for target: UIView)
    func onViewDidAppear(for target: UIView)
}

final class EventDrivenKeyboardStrategy: KeyboardAppearanceStrategyProtocol {
    enum EventType {
        case viewWillAppear
        case viewDidAppear
    }

    let events: Set<EventType>

    init(events: Set<EventType>) {
        self.events = events
    }

    func onViewWillAppear(for target: UIView) {
        if events.contains(.viewWillAppear) {
            target.becomeFirstResponder()
        }
    }

    func onViewDidAppear(for target: UIView) {
        if events.contains(.viewDidAppear) {
            target.becomeFirstResponder()
        }
    }
}

final class ModalNavigationKeyboardStrategy: KeyboardAppearanceStrategyProtocol {
    var isPresented: Bool = false

    func onViewWillAppear(for target: UIView) {
        if !isPresented {
            target.becomeFirstResponder()
        }
    }

    func onViewDidAppear(for target: UIView) {
        if isPresented {
            target.becomeFirstResponder()
        } else {
            isPresented = true
        }
    }
}
