import UIKit

public extension UIView {
    static func create<View: UIView>(with mutation: (View) -> Void) -> View {
        let view = View()
        mutation(view)
        return view
    }
}
