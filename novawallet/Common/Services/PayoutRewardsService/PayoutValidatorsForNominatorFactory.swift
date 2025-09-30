import Operation_iOS
import Foundation
import SubstrateSdk
import NovaCrypto

final class PayoutValidatorsForNominatorFactory {
    let urls: [URL]

    init(urls: [URL]) {
        self.urls = urls
    }
}

// MARK: - Private

private extension PayoutValidatorsForNominatorFactory {
    func createWrapper(
        address: AccountAddress,
        historyRange: @escaping () throws -> Staking.EraRange
    ) -> CompoundOperationWrapper<Set<ResolvedValidatorEra>> {
        let networkOperations = urls.map {
            let requestFactory = createRequestFactory(
                for: $0,
                address: address,
                historyRange: historyRange
            )

            let resultFactory = createResultFactory()

            return NetworkOperation(
                requestFactory: requestFactory,
                resultFactory: resultFactory
            )
        }

        let resultOperation = ClosureOperation<Set<ResolvedValidatorEra>> {
            try networkOperations
                .map { try $0.extractNoCancellableResultData() }
                .reduce(Set<ResolvedValidatorEra>()) { $0.union($1) }
        }

        networkOperations.forEach { resultOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: networkOperations
        )
    }

    func createRequestFactory(
        for url: URL,
        address: AccountAddress,
        historyRange: @escaping () throws -> Staking.EraRange
    ) -> NetworkRequestFactoryProtocol {
        BlockNetworkRequestFactory {
            var request = URLRequest(url: url)

            let eraRange = try historyRange()
            let params = self.requestParams(accountAddress: address, eraRange: eraRange)
            let info = JSON.dictionaryValue(["query": JSON.stringValue(params)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )
            request.httpMethod = HttpMethod.post.rawValue
            return request
        }
    }

    func createResultFactory() -> AnyNetworkResultFactory<Set<ResolvedValidatorEra>> {
        AnyNetworkResultFactory<Set<ResolvedValidatorEra>> { data in
            guard
                let resultData = try? JSONDecoder().decode(JSON.self, from: data),
                let nodes = resultData.data?.query?.eraValidatorInfos?.nodes?.arrayValue
            else { return [] }

            let validators: [ResolvedValidatorEra] = try nodes.compactMap { node in
                guard
                    let address = node.address?.stringValue,
                    let era = node.era?.unsignedIntValue else {
                    return nil
                }

                let accountId = try address.toAccountId()

                return ResolvedValidatorEra(validator: accountId, era: Staking.EraIndex(era))
            }

            return Set(validators)
        }
    }

    func requestParams(accountAddress: AccountAddress, eraRange: Staking.EraRange) -> String {
        let start = eraRange.start
        let end = eraRange.end
        let eraFilter: String = "era:{greaterThanOrEqualTo: \(start), lessThanOrEqualTo: \(end)},"

        return """
        {
          query {
            eraValidatorInfos(
              orderBy: ERA_DESC,
              filter:{
                \(eraFilter)
                others:{contains:[{who:\"\(accountAddress)\"}]}
              }
            ) {
              nodes {
                address
                era
              }
            }
          }
        }
        """
    }
}

// MARK: - PayoutValidatorsFactoryProtocol

extension PayoutValidatorsForNominatorFactory: PayoutValidatorsFactoryProtocol {
    func createResolutionOperation(
        for address: AccountAddress,
        eraRangeClosure: @escaping () throws -> Staking.EraRange
    ) -> CompoundOperationWrapper<Set<ResolvedValidatorEra>> {
        createWrapper(
            address: address,
            historyRange: { try eraRangeClosure() }
        )
    }
}
