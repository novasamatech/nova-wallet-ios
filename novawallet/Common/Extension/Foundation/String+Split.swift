extension String {
    enum Separator: String.Element {
        case slash = "/"
        case colon = ":"
        case hashtag = "#"
        case space = " "
        case comma = ","
        case dot = "."
        case dash = "-"
    }

    enum CompoundSeparator: String {
        case commaSpace = ", "
        case colonSpace = ": "
        case newLine = "\n"
    }

    func split(by separator: Separator, maxSplits: Int = .max) -> [String] {
        split(separator: separator.rawValue, maxSplits: maxSplits).map { String($0) }
    }
}

extension Array where Array.Element == String {
    func joined(with separator: String.CompoundSeparator) -> String {
        joined(separator: separator.rawValue)
    }

    func joined(with separator: String.Separator) -> String {
        joined(separator: String(separator.rawValue))
    }
}
