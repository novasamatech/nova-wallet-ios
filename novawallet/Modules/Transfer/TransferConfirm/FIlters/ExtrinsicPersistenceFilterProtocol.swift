protocol ExtrinsicPersistenceFilterProtocol {
    func canPersistExtrinsic(for sender: ChainAccountResponse) -> Bool
}
