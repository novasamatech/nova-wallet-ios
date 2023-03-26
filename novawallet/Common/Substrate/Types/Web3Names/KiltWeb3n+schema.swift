extension KiltW3n {
    static let schema: String = "w3n"

    static func match(_ schema: String?) -> Bool {
        guard let schema = schema else {
            return false
        }
        return KiltW3n.schema.compare(schema, options: .caseInsensitive) == .orderedSame
    }
}
