import UIKit

extension MultigradientView {
    static var background: MultigradientView {
        let view = MultigradientView()

        view.startPoint = CGPoint(x: 0.5, y: 0.0)
        view.endPoint = CGPoint(x: 0.5, y: 1.0)

        view.colors = [
            UIColor(hex: "#6703A0")!,
            UIColor(hex: "#490C75")!,
            UIColor(hex: "#183A91")!,
            UIColor(hex: "#104677")!
        ]

        view.locations = [0.0, 0.2304, 0.4826, 1.0]

        return view
    }
}
