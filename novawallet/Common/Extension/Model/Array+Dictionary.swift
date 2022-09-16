import Foundation
import RobinHood

extension Array where Array.Element: Identifiable {
    func reduceToDict(_ currentDict: [String: Array.Element] = [:]) -> [String: Array.Element] {
        reduce(into: currentDict) { result, model in
            result[model.identifier] = model
        }
    }
}
