import SubstrateSdk

extension Array where Element: Identifiable {
    mutating func upsertFirst(_ element: Element) {
        if let index = firstIndex(where: { $0.identifier == element.identifier }) {
            self[index] = element
        } else {
            append(element)
        }
    }
}
