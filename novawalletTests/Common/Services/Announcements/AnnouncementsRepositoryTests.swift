import XCTest
@testable import novawallet
import Cuckoo
import Operation_iOS

final class AnnouncementsRepositoryTests: XCTestCase {
    private let validJson = """
    {
      "staking": [
        {
          "chainId": "0x91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3",
          "style": "warning",
          "description": { "default": "Staking maintenance" }
        },
        {
          "style": "info",
          "description": { "default": "General notice" }
        }
      ],
      "governance": [
        {
          "style": "error",
          "description": { "default": "Governance only" }
        }
      ]
    }
    """

    func testConsecutiveFetchesHitNetworkOnceAndReturnSameAnnouncements() throws {
        // given
        let factory = createSuccessFactory()
        let repository = createRepository(fetchFactory: factory)

        // when
        let firstResult = fetchAnnouncements(using: repository)
        let secondResult = fetchAnnouncements(using: repository)

        // then
        XCTAssertEqual(firstResult, try expectedStakingAnnouncements())
        XCTAssertEqual(firstResult, secondResult)

        verify(factory, times(1)).fetchOperation()
    }

    func testFailedFetchYieldsEmptyListAndIsNotCached() throws {
        // given
        let factory = MockAnnouncementsFetchOperationFactoryProtocol()

        let failureOperation: BaseOperation<AnnouncementsRemote> = .createWithError(
            NetworkBaseError.unexpectedEmptyData
        )
        let successOperation: BaseOperation<AnnouncementsRemote> = createSuccessOperation()

        stub(factory) { stub in
            stub.fetchOperation().thenReturn(failureOperation, successOperation)
        }

        let repository = createRepository(fetchFactory: factory)

        // when
        let firstResult = fetchAnnouncements(using: repository)
        let secondResult = fetchAnnouncements(using: repository)

        // then
        XCTAssertTrue(firstResult.isEmpty)
        XCTAssertEqual(secondResult, try expectedStakingAnnouncements())

        verify(factory, times(2)).fetchOperation()
    }

    func testFetchReturnsOnlyRequestedSection() throws {
        // given
        let repository = createRepository(fetchFactory: createSuccessFactory())

        // when
        let result = fetchAnnouncements(using: repository)

        // then
        XCTAssertEqual(result, try expectedStakingAnnouncements())
        XCTAssertEqual(result.count, 2)
        XCTAssertFalse(
            result.contains { $0.message(for: Locale(identifier: "en")) == "Governance only" }
        )
    }

    // MARK: - Private

    private func createSuccessFactory() -> MockAnnouncementsFetchOperationFactoryProtocol {
        let factory = MockAnnouncementsFetchOperationFactoryProtocol()

        stub(factory) { stub in
            stub.fetchOperation().then { [validJson] in
                ClosureOperation {
                    try JSONDecoder().decode(AnnouncementsRemote.self, from: Data(validJson.utf8))
                }
            }
        }

        return factory
    }

    private func createSuccessOperation() -> BaseOperation<AnnouncementsRemote> {
        ClosureOperation { [validJson] in
            try JSONDecoder().decode(AnnouncementsRemote.self, from: Data(validJson.utf8))
        }
    }

    private func createRepository(
        fetchFactory: AnnouncementsFetchOperationFactoryProtocol
    ) -> AnnouncementsRepositoryProtocol {
        AnnouncementsRepository(
            fetchOperationFactory: fetchFactory,
            logger: Logger.shared
        )
    }

    private func fetchAnnouncements(using repository: AnnouncementsRepositoryProtocol) -> [Announcement] {
        let wrapper = repository.fetchAnnouncementsWrapper(for: .staking)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return (try? wrapper.targetOperation.extractNoCancellableResultData()) ?? []
    }

    private func expectedStakingAnnouncements() throws -> [Announcement] {
        let remote = try JSONDecoder().decode(
            AnnouncementsRemote.self,
            from: Data(validJson.utf8)
        )

        return remote.announcements(for: .staking)
    }
}
