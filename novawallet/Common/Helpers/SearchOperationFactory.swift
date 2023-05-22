import Foundation
import RobinHood

enum SearchOperationFactory {
    private static func pointsForWord(title: String, word: String) -> UInt {
        if word.caseInsensitiveCompare(title) == .orderedSame {
            return 1000
        } else if title.range(of: word, options: .caseInsensitive) != nil {
            return 1
        } else {
            return 0
        }
    }

    private static func pointsForPhrase(title: String, phrase: String) -> UInt {
        let pattern = phrase.replacingOccurrences(of: " ", with: ".*")
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return 0
        }
        let match = regex.firstMatch(
            in: title,
            range: NSRange(title.startIndex..., in: title)
        )
        return match != nil ? 1 : 0
    }

    static func searchOperation<Model, Key>(
        text: String,
        in models: [Model],
        keyExtractor: @escaping (Model) -> Key,
        searchKeysExtractor: @escaping (Key) -> [String]
    ) -> BaseOperation<[Model]> where Key: Hashable {
        ClosureOperation {
            guard !text.isEmpty else {
                return models
            }
            let calculatePoints = text.split(
                by: .space,
                maxSplits: 1
            ).count > 1 ? self.pointsForPhrase : self.pointsForWord

            let weights = models.reduce(into: [Key: UInt]()) { result, item in
                let key = keyExtractor(item)
                let searchWords = searchKeysExtractor(key)
                result[key] = searchWords.reduce(0) {
                    $0 + calculatePoints($1, text)
                }
            }

            let result = models
                .filter {
                    weights[keyExtractor($0), default: 0] > 0
                }
                .sorted {
                    weights[keyExtractor($0), default: 0] > weights[keyExtractor($1), default: 0]
                }

            return result
        }
    }
}
