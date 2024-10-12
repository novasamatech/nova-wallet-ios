import Foundation

private let filePath = "R.generated.swift"

@main
enum ModifyRGenerated {
    static func main() {
        do {
            var content = try String(contentsOfFile: filePath, encoding: .utf8)

            content = content.replacingOccurrences(
                of: "preferredLanguages: [String])",
                with: "preferredLanguages: [String]? = [])"
            )

            content = content.replacingOccurrences(
                of: "preferredLanguages: [String],",
                with: "preferredLanguages: [String]? = [],"
            )

            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to read or modify the file: \(error)")
        }
    }
}
