extension String {
    enum Separator: String.Element {
        case slash = "/"
        case colon = ":"
    }

    func split(by separator: Separator) -> [String] {
        split(separator: separator.rawValue).map { String($0) }
    }
}
