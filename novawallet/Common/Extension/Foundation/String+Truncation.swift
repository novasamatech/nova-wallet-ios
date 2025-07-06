import Foundation

extension String {
    var truncated: String {
        truncated(prefix: 4, suffix: 5)
    }

    var shortTruncated: String {
        truncated
    }

    var mediumTruncated: String {
        truncated(prefix: 6, suffix: 7)
    }

    func truncated(prefix: Int, suffix: Int) -> String {
        guard count > prefix + suffix else {
            return self
        }

        let prefixString = self.prefix(prefix)
        let suffixString = self.suffix(suffix)

        return "\(prefixString)...\(suffixString)"
    }
}
