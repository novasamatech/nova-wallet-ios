import Operation_iOS
import Foundation
import SubstrateSdk
import NovaCrypto

final class PayoutValidatorsForNominatorFactory {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    private func createRequestFactory(
        address: AccountAddress,
        historyRange: @escaping () throws -> EraRange
    ) -> NetworkRequestFactoryProtocol {
        BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

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

    private func createResultFactory() -> AnyNetworkResultFactory<Set<ResolvedValidatorEra>> {
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

                return ResolvedValidatorEra(validator: accountId, era: EraIndex(era))
            }

            return Set(validators)
        }
    }

    private func requestParams(accountAddress: AccountAddress, eraRange: EraRange) -> String {
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

extension PayoutValidatorsForNominatorFactory: PayoutValidatorsFactoryProtocol {
    func createResolutionOperation(
        for address: AccountAddress,
        eraRangeClosure: @escaping () throws -> EraRange
    ) -> CompoundOperationWrapper<Set<ResolvedValidatorEra>> {
        let requestFactory = createRequestFactory(address: address, historyRange: { try eraRangeClosure() })
        let resultFactory = createResultFactory()

        let networkOperation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        return CompoundOperationWrapper(targetOperation: networkOperation)
    }
}
