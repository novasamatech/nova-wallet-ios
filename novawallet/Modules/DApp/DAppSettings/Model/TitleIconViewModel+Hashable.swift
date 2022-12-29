extension TitleIconViewModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(icon)
    }
}
