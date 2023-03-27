extension KiltW3n {
    static let schema: String = "w3n"

    static func web3Name(nameWithScheme: String) -> String? {
        let nameWithScheme = nameWithScheme.split(by: .colon)
        guard let scheme = nameWithScheme[safe: 0]?.trimmingCharacters(in: .whitespacesAndNewlines),
              KiltW3n.schema.compare(scheme, options: .caseInsensitive) == .orderedSame else {
            return nil
        }

        return nameWithScheme[safe: 1]
    }

    static func fullName(for name: String) -> String {
        if web3Name(nameWithScheme: name) != nil {
            return name
        } else {
            return [schema, name].joined(separator: String(String.Separator.colon.rawValue))
        }
    }
}
