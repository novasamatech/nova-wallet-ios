import XCTest
@testable import novawallet
import Operation_iOS
import NovaCrypto

class ManagedAccountItemMapperTests: XCTestCase {
    func testSaveAndFetchItem() throws {
        // given

        let operationQueue = OperationQueue()

        let repository = AccountRepositoryFactory(storageFacade: UserDataStorageTestFacade())
            .createManagedMetaAccountRepository(
                for: nil,
                sortDescriptors: [NSSortDescriptor.accountsByOrder]
            )

        // when
        let keypair = try SECKeyFactory().createRandomKeypair()
        let address = try keypair.publicKey().rawData().toAddress(using: .substrate(2))

        let accountId = try keypair.publicKey().rawData().publicKeyToAccountId()

        let metaAccountItem = MetaAccountModel(
            metaId: UUID().uuidString,
            name: "metaAccount",
            substrateAccountId: accountId,
            substrateCryptoType: MultiassetCryptoType.substrateEcdsa.rawValue,
            substratePublicKey: keypair.publicKey().rawData(),
            ethereumAddress: address.asSecretData(),
            ethereumPublicKey: keypair.publicKey().rawData(),
            chainAccounts: [],
            type: .secrets,
            multisig: nil
        )

        let accountItem = ManagedMetaAccountModel(
            info: metaAccountItem,
            isSelected: true,
            order: 1
        )

        let saveOperation = repository.saveOperation({ [accountItem] }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)

        // then
        XCTAssertNoThrow(try saveOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled))

        // when
        let receivedAccountItem = try fetchOperation.extractResultData()

        // then
        XCTAssertEqual([accountItem], receivedAccountItem)
    }
}
