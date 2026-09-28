import Foundation

extension SubtensorEarnConfig {
    static let bundled: SubtensorEarnConfig? = {
        guard
            let url = R.file.subtensorEarnConfigJson(),
            let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(SubtensorEarnConfig.self, from: data)
    }()
}
