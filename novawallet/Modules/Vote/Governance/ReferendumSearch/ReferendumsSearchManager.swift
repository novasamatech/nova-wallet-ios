import RobinHood

final class ReferendumsSearchManager {
    let cells: [ReferendumsCellViewModel]
    let searchKeysExtractor: (ReferendumIdLocal) -> [String]
    let keyExtractor: (ReferendumsCellViewModel) -> ReferendumIdLocal

    init(cells: [ReferendumsCellViewModel]) {
        self.cells = cells

        let mappedCells = cells.reduce(into: [ReferendumIdLocal: ReferendumsCellViewModel]()) { result, element in
            result[element.referendumIndex] = element
        }

        keyExtractor = { referendum in
            referendum.referendumIndex
        }

        searchKeysExtractor = { referendumId in
            [
                mappedCells[referendumId]?.viewModel.value?.referendumInfo.title,
                "\(referendumId)"
            ].compactMap { $0 }
        }
    }

    func searchOperation(text: String) -> BaseOperation<[ReferendumsCellViewModel]> {
        SearchOperationFactory.searchOperation(
            text: text,
            in: cells,
            keyExtractor: keyExtractor,
            searchKeysExtractor: searchKeysExtractor
        )
    }
}
