import Foundation

enum TableViewCellPosition {
    case single
    case top
    case middle
    case bottom

    init(row: Int, count: Int) {
        if count > 1 {
            if row == count - 1 {
                self = .bottom
            } else if row == 0 {
                self = .top
            } else {
                self = .middle
            }
        } else {
            self = .single
        }
    }
}
