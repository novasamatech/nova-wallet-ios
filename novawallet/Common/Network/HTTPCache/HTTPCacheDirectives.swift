import Foundation

enum HTTPCacheDirectives: Equatable {
    case reusable(lifetime: TimeInterval)
    case notStorable

    init(response: HTTPURLResponse) {
        self.init(
            cacheControl: response.value(forHTTPHeaderField: Constants.cacheControlHeader),
            age: response.value(forHTTPHeaderField: Constants.ageHeader)
        )
    }

    init(cacheControl: String?, age: String?) {
        guard let maxAge = cacheControl.flatMap({ Self.usableMaxAge(in: $0) }) else {
            self = .notStorable
            return
        }

        let lifetime = maxAge - Self.ageSeconds(in: age)

        self = lifetime > 0 ? .reusable(lifetime: TimeInterval(lifetime)) : .notStorable
    }
}

private extension HTTPCacheDirectives {
    enum Constants {
        static let cacheControlHeader = "Cache-Control"
        static let ageHeader = "Age"
        static let noStoreDirective = "no-store"
        static let noCacheDirective = "no-cache"
        static let maxAgeDirective = "max-age"
        static let memberSeparator: Character = ","
        static let argumentSeparator: Character = "="
        static let quote: Character = "\""
        static let optionalWhitespace = CharacterSet(charactersIn: " \t")
        static let asciiDigits = CharacterSet(charactersIn: "0123456789")
        static let maxDeltaSeconds = 2_147_483_648
    }

    struct Directive {
        let name: String
        let argument: String?

        var forbidsStorage: Bool {
            name == Constants.noStoreDirective || name == Constants.noCacheDirective
        }

        init(member: String) {
            guard let separatorIndex = member.firstIndex(of: Constants.argumentSeparator) else {
                name = member.lowercased()
                argument = nil
                return
            }

            name = member[..<separatorIndex].lowercased()
            argument = String(member[member.index(after: separatorIndex)...])
        }
    }

    static func usableMaxAge(in cacheControl: String) -> Int? {
        let directives = members(of: cacheControl).map { Directive(member: $0) }
        let maxAgeDirectives = directives.filter { $0.name == Constants.maxAgeDirective }

        guard
            !directives.contains(where: { $0.forbidsStorage }),
            maxAgeDirectives.count == 1,
            let argument = maxAgeDirectives.first?.argument else {
            return nil
        }

        return deltaSeconds(in: unquoted(argument))
    }

    static func ageSeconds(in age: String?) -> Int {
        guard let firstMember = age.flatMap({ members(of: $0).first }) else {
            return 0
        }

        return deltaSeconds(in: firstMember) ?? 0
    }

    static func members(of fieldValue: String) -> [String] {
        fieldValue
            .split(separator: Constants.memberSeparator)
            .map { $0.trimmingCharacters(in: Constants.optionalWhitespace) }
            .filter { !$0.isEmpty }
    }

    static func unquoted(_ argument: String) -> String {
        guard argument.count > 1, argument.first == Constants.quote, argument.last == Constants.quote else {
            return argument
        }

        return String(argument.dropFirst().dropLast())
    }

    static func deltaSeconds(in text: String) -> Int? {
        guard !text.isEmpty, text.unicodeScalars.allSatisfy({ Constants.asciiDigits.contains($0) }) else {
            return nil
        }

        return min(Int(text) ?? Constants.maxDeltaSeconds, Constants.maxDeltaSeconds)
    }
}
