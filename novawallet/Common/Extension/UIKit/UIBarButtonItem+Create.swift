import UIKit

extension UIBarButtonItem {
    static func create<View: UIBarButtonItem>(with mutation: (View) -> Void) -> View {
        let view = View()
        mutation(view)
        return view
    }
}
