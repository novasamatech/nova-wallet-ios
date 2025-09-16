import Foundation
@testable import novawallet

// Optics in functional programming
struct GenericPrism<Whole, Part> {
    let get: (Whole) -> Part?
    let inject: (Part) -> Whole

    init(get: @escaping (Whole) -> Part?, inject: @escaping (Part) -> Whole) {
        self.get = get
        self.inject = inject
    }

    func then<Subpart>(_ other: GenericPrism<Part, Subpart>) -> GenericPrism<Whole, Subpart> {
        GenericPrism<Whole, Subpart>(
            get: { self.get($0).flatMap(other.get) },
            inject: { self.inject(other.inject($0)) }
        )
    }
}

enum Prism {
    static var contributionViewModels: GenericPrism<CrowdloanYourContributionsSection, [CrowdloanContributionViewModel]> {
        .init(
            get: {
                guard case let .contributions(output) = $0 else {
                    return nil
                }
                return output
            },
            inject: { .contributions($0) }
        )
    }
}
