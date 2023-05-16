import RobinHood

final class ReferendumsSearchManager {
    let cells: [ReferendumsCellViewModel]
    let searchKeyExtractor: (ReferendumIdLocal) -> String
    let keyExtractor: (ReferendumsCellViewModel) -> ReferendumIdLocal

    init(cells: [ReferendumsCellViewModel]) {
        self.cells = cells

        let mappedCells = cells.reduce(into: [ReferendumIdLocal: ReferendumsCellViewModel]()) { result, element in
            result[element.referendumIndex] = element
        }

        searchKeyExtractor = {
            mappedCells[$0]?.viewModel.value?.referendumInfo.title ?? "\($0)"
        }

        keyExtractor = {
            $0.referendumIndex
        }
    }

    func searchOperation(text: String) -> BaseOperation<[ReferendumsCellViewModel]> {
        SearchOperationFactory.searchOperation(
            text: text,
            in: cells,
            keyExtractor: keyExtractor,
            searchKeyExtractor: searchKeyExtractor
        )
    }
}
