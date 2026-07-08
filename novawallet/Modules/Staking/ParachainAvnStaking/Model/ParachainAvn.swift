import Foundation

/// Empty namespace enum for Energy Web X's `ParachainStaking` pallet
/// integration (Aventus AvN fork). Call structs, storage-path factories,
/// and constant-path factories all live under `extension ParachainAvn`
/// in sibling files so consumers see a single `ParachainAvn.*` prefix.
///
/// This is deliberately separate from Nova's existing `ParachainStaking`
/// namespace (used by the Moonbeam-family integration). The two chains
/// share a pallet name and many storage item names, but the call names
/// diverged when Moonbeam renamed `nominate`/`nominator_*` to
/// `delegate`/`delegator_*`. EWX kept the older AvN names. Mixing the
/// two namespaces would produce invalid extrinsics at sign time.
enum ParachainAvn {}
