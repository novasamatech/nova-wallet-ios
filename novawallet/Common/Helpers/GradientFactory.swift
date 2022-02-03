import Foundation
import UIKit

final class CSSGradientFactory {
    func createFromString(_ cssString: String) -> GradientModel? {
        guard let arguments = extractArguments(from: cssString), arguments.count > 1 else {
            return nil
        }

        let normalizedArguments = arguments.map { $0.trimmingCharacters(in: .whitespaces) }

        guard
            let angleParam = normalizedArguments.first,
            let cssAngle = extractAngle(from: angleParam) else {
            return nil
        }

        let normalizedAngle = (360 - cssAngle.quantized(by: 45) + 90) % 360

        let colorAndLocations: [(UIColor, Float)] = normalizedArguments.dropFirst().compactMap { param in
            guard let colorAndLocation = extractColorAndLocation(from: param) else {
                return nil
            }

            return colorAndLocation
        }

        guard colorAndLocations.count == normalizedArguments.count - 1 else {
            return nil
        }

        let colors = colorAndLocations.map(\.0)
        let locations = colorAndLocations.map(\.1)

        return GradientModel(
            angle: normalizedAngle,
            colors: colors,
            locations: locations
        )
    }

    private func extractArguments(from cssString: String) -> [String]? {
        do {
            let pattern = "linear-gradient\\(([0-9.]+deg(?:,\\s*#[0-9A-F]{6} [0-9.]+%)*)\\)"

            let regularExpression = try NSRegularExpression(pattern: pattern)

            let matches = regularExpression.matches(
                in: cssString,
                options: [],
                range: NSRange(location: 0, length: cssString.utf16.count)
            )

            guard let match = matches.first, match.numberOfRanges > 1 else {
                return nil
            }

            let arguments = (cssString as NSString).substring(with: match.range(at: 1))

            return arguments.components(separatedBy: ",")

        } catch {
            return nil
        }
    }

    private func extractAngle(from param: String) -> Int? {
        do {
            let pattern = "([0-9.]+)deg"

            let regularExpression = try NSRegularExpression(pattern: pattern)

            let matches = regularExpression.matches(
                in: param,
                options: [],
                range: NSRange(location: 0, length: param.utf16.count)
            )

            guard let match = matches.first, match.numberOfRanges > 1 else {
                return nil
            }

            let angleString = (param as NSString).substring(with: match.range(at: 1))

            guard let angle = Double(angleString) else {
                return nil
            }

            return Int(angle)

        } catch {
            return nil
        }
    }

    private func extractColorAndLocation(from param: String) -> (UIColor, Float)? {
        do {
            let pattern = "(#[0-9A-F]{6}) ([0-9.]+)%"

            let regularExpression = try NSRegularExpression(pattern: pattern)

            let matches = regularExpression.matches(
                in: param,
                options: [],
                range: NSRange(location: 0, length: param.utf16.count)
            )

            guard let match = matches.first, match.numberOfRanges > 2 else {
                return nil
            }

            let colorString = (param as NSString).substring(with: match.range(at: 1))
            let percentageString = (param as NSString).substring(with: match.range(at: 2))

            guard let color = UIColor(hex: colorString) else {
                return nil
            }

            guard let percentage = Float(percentageString) else {
                return nil
            }

            let location = percentage / 100.0

            guard location >= 0.0, location <= 1.0 else {
                return nil
            }

            return (color, location)

        } catch {
            return nil
        }
    }
}
