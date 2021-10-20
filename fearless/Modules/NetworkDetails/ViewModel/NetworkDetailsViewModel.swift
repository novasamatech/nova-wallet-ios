import Foundation

struct NetworkDetailsViewModel {
    let title: String
    let sections: [NetworkDetailsSection]
    let actionTitle: String
}

extension NetworkDetailsViewModel {
    var customNodesSectionIndex: Int? {
        for (index, section) in sections.enumerated() {
            if case NetworkDetailsSection.customNodes = section {
                return index
            }
        }
        return nil
    }
}
