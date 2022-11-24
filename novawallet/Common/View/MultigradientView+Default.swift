import UIKit

extension MultigradientView {
    static var background: MultigradientView {
        let view = MultigradientView()

        view.startPoint = CGPoint(x: 0.5, y: 0.0)
        view.endPoint = CGPoint(x: 0.5, y: 1.0)

        view.colors = [
            R.color.colorGradientBlockBackgroundFirstPart()!,
            R.color.colorGradientBlockBackgroundSecondPart()!,
            R.color.colorGradientBlockBackgroundThirdPart()!
        ]

        return view
    }
}
