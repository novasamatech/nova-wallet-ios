import Foundation

final class VoteCardPanState {
    struct ResolvedDirection {
        let direction: CardsZStack.DismissalDirection
        let priority: Int
    }

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    let minNeededTranslation: CGFloat

    init(minNeededTranslation: CGFloat = 100) {
        self.minNeededTranslation = minNeededTranslation
    }

    private func resolveLeft(for start: CGPoint, end: CGPoint) -> ResolvedDirection? {
        let diff = end.x - start.x
        let length = abs(diff)

        guard diff < 0, length >= minNeededTranslation else {
            return nil
        }

        return .init(direction: .left, priority: Int(length))
    }

    private func resolveRight(for start: CGPoint, end: CGPoint) -> ResolvedDirection? {
        let diff = end.x - start.x

        guard diff > 0, diff >= minNeededTranslation else {
            return nil
        }

        return .init(direction: .right, priority: Int(diff))
    }

    private func resolveTop(for start: CGPoint, end: CGPoint) -> ResolvedDirection? {
        let diff = end.y - start.y
        let length = abs(diff)

        guard diff < 0, length >= minNeededTranslation else {
            return nil
        }

        return .init(direction: .top, priority: Int(length) / 2)
    }
}

extension VoteCardPanState {
    func predictDirection() -> CardsZStack.DismissalDirection? {
        guard let startPoint, let currentPoint else {
            return nil
        }

        let possibleDirections = [
            resolveLeft(for: startPoint, end: currentPoint),
            resolveRight(for: startPoint, end: currentPoint),
            resolveTop(for: startPoint, end: currentPoint)
        ].compactMap { $0 }

        return possibleDirections.max(by: { $0.priority < $1.priority })?.direction
    }

    func onPanBegin(point: CGPoint) {
        startPoint = point
        currentPoint = nil
    }

    func onPanChange(point: CGPoint) {
        currentPoint = point
    }
}
