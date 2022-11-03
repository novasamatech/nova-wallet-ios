import UIKit

extension UITableView {
    func registerClassForCell(_ cellClass: UITableViewCell.Type) {
        register(cellClass, forCellReuseIdentifier: cellClass.reuseIdentifier)
    }

    func unregisterClassForCell(_ cellClass: UITableViewCell.Type) {
        let registeredClass: UITableViewCell.Type? = nil
        register(registeredClass, forCellReuseIdentifier: cellClass.reuseIdentifier)
    }

    func registerClassesForCell(_ cellClasses: [UITableViewCell.Type]) {
        cellClasses.forEach { cellClass in
            register(cellClass, forCellReuseIdentifier: cellClass.reuseIdentifier)
        }
    }

    func registerHeaderFooterView(withClass viewClass: UITableViewHeaderFooterView.Type) {
        register(viewClass, forHeaderFooterViewReuseIdentifier: viewClass.reuseIdentifier)
    }

    func unregisterHeaderFooterView(withClass viewClass: UITableViewHeaderFooterView.Type) {
        let registeredView: UITableViewHeaderFooterView.Type? = nil
        register(registeredView, forHeaderFooterViewReuseIdentifier: viewClass.reuseIdentifier)
    }

    func dequeueReusableCellWithType<T: UITableViewCell>(_ cellClass: T.Type) -> T? {
        dequeueReusableCell(withIdentifier: cellClass.reuseIdentifier) as? T
    }

    func dequeueReusableCell<T: UITableViewCell>(for indexPath: IndexPath) -> T {
        guard let cell = dequeueReusableCell(withIdentifier: T.reuseIdentifier, for: indexPath) as? T else {
            fatalError("Could not dequeue cell with identifier: \(T.reuseIdentifier)")
        }
        return cell
    }

    func dequeueReusableCellWithType<T: UITableViewCell>(
        _ cellClass: T.Type,
        forIndexPath indexPath: IndexPath
    ) -> T {
        guard let cell = dequeueReusableCell(
            withIdentifier: cellClass.reuseIdentifier,
            for: indexPath
        ) as? T else {
            fatalError("You are trying to dequeue \(cellClass) which is not registered")
        }
        return cell
    }

    func dequeueReusableHeaderFooterView<T: UITableViewHeaderFooterView>() -> T {
        guard let view = dequeueReusableHeaderFooterView(withIdentifier: T.reuseIdentifier) as? T else {
            fatalError("You are trying to dequeue header of footer which is not registered")
        }
        return view
    }
}

extension UIView {
    static var reuseIdentifier: String {
        NSStringFromClass(self)
    }
}
