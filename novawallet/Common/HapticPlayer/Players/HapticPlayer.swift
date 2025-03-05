protocol HapticPlayer {
    func play()
}

protocol ProgressiveHapticPlayer: HapticPlayer {
    func reset()
}
