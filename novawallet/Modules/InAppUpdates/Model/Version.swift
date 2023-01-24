struct Version: Decodable, Hashable {
    let major: UInt
    let minor: UInt
    let patch: UInt

    var id: String {
        [major, minor, patch].map { String($0) }.joined(separator: ".")
    }

    init(major: UInt, minor: UInt, patch: UInt) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.singleValueContainer()
        let version = try container.decode(String.self)
        guard let version = Self.parse(from: version) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Can't parse version"
            )
        }
        major = version.major
        minor = version.minor
        patch = version.patch
    }

    static func parse(from string: String, separator _: String = ".") -> Self? {
        let versionComponents = string.split(separator: ".")
        guard
            let major = UInt(versionComponents[0]),
            let minor = UInt(versionComponents[safe: 1] ?? "0"),
            let patch = UInt(versionComponents[safe: 2] ?? "0") else {
            return nil
        }

        return Version(major: major, minor: minor, patch: patch)
    }
}

extension Version: Comparable {
    static func < (lhs: Version, rhs: Version) -> Bool {
        guard lhs.major == rhs.major else {
            return lhs.major < rhs.major
        }
        guard lhs.minor == rhs.minor else {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}
