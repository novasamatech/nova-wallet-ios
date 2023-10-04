import UIKit

protocol KeyboardAppearanceStrategyProtocol {
    func onViewWillAppear(for target: UIView)
    func onViewDidAppear(for target: UIView)
    func onCellSelected(for target: UIView)
}

extension KeyboardAppearanceStrategyProtocol {
    func onCellSelected(for _: UIView) {}
}

final class EventDrivenKeyboardStrategy: KeyboardAppearanceStrategyProtocol {
    enum EventType {
        case viewWillAppear
        case viewDidAppear
    }

    let events: Set<EventType>
    let triggersOnes: Bool

    private var triggered: Bool = false

    private var canTrigger: Bool {
        !(triggersOnes && triggered)
    }

    init(events: Set<EventType>, triggersOnes: Bool = false) {
        self.events = events
        self.triggersOnes = triggersOnes
    }

    func onViewWillAppear(for target: UIView) {
        if canTrigger, events.contains(.viewWillAppear) {
            target.becomeFirstResponder()
            triggered = true
        }
    }

    func onViewDidAppear(for target: UIView) {
        if canTrigger, events.contains(.viewDidAppear) {
            target.becomeFirstResponder()
            triggered = true
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

    func onCellSelected(for target: UIView) {
        if isPresented {
            target.resignFirstResponder()
        }
    }
}
