import UIKit

extension MultigradientView {
    static var background: MultigradientView {
        createBackground(for: .init(x: 0.5, y: 0.13), radius: .init(x: 2.22, y: 0.87))
    }

    private static func createBackground(for center: CGPoint, radius: CGPoint) -> MultigradientView {
        let view = MultigradientView()
        view.gradientType = .radial

        view.startPoint = center
        view.endPoint = radius

        view.locations = [0.0, 0.46, 1.0]

        view.colors = [
            R.color.colorGradientBlockBackgroundFirstPart()!,
            R.color.colorGradientBlockBackgroundSecondPart()!,
            R.color.colorGradientBlockBackgroundThirdPart()!
        ]

        return view
    }
}
