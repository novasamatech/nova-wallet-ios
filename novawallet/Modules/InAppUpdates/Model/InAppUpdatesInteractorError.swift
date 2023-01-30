enum InAppUpdatesInteractorError: Error {
    case fetchAllChangeLogs(Error)
    case fetchLastVersionChangeLog(Error)
}
