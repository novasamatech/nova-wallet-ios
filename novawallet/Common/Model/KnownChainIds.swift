import Foundation

enum KnowChainId {
    static let kusama = "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe"
    static let kusamaAssetHub = "48239ef607d7928874027a43a67689209727dfb3d3dc5e5b03a39bdc2eda771a"
    static let polkadot = "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
    static let polkadotAssetHub = "68d56f15f85d3136970ec16946040bc1752654e906147f7e43e9d539d7c3de2f"

    static let unique = "84322d9cddbf35088f1e54e9a85c967a41a56a4f43445768125e61af166c7d31"
    static let acala = "fc41b9bd8ef8fe53d58c7ea67c794c7ec9a73daf05e6d54b14ff6342c99ba64c"
    static let edgeware = "742a2ca70c2fda6cee4f8df98d64c4c670a052d9568058982dad9d5a7a135c5b"
    static let karura = "baf5aabe40646d11f0ee8abbdc64f4a4b7674925cba08e4a05ff9ebed6e2126b"
    static let nodle = "97da7ede98d7bad4e36b4d734b6055425a3be036da2a332ea5a7037656427a21"
    static let polymesh = "6fbd74e5e1d0a61d52ccfe9d4adaed16dd3a7caa37c6bc4d0c2fa12e8b2f4063"
    static let centrifuge = "b3db41421702df9a7fcac62b53ffeac85f7853cc4e689e0b93aeb3db18c09d82"
    static let xxNetwork = "50dd5d206917bf10502c68fb4d18a59fc8aa31586f4e8856b493e43544aa82aa"
    static let astar = "9eb76c5184c4ab8679d2d5d819fdf90b9c001403e9e17da2e14b6d8aec4029c6"
    static let kiltPelegrine = "a0c6e3bac382b316a68bca7141af1fba507207594c761076847ce358aeedcc21"
    static let kiltSpiritnet = "411f057b9107718c9624d6aa4a3f23c1653898297f3d4d529d9bb6511a39dd21"
    static let moonbeam = "fe58ea77779b7abda7da4ec526d14db9b1e9cd40a217c34892af80a9b332b76d"
    static let moonriver = "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b"
    static let alephZero = "70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e"
    static let ternoa = "6859c81ca95ef624c9dfe4dc6e3381c33e5d6509e35e147092bfbc780f777c4e"
    static let polkadex = "3920bcb4960a1eef5580cd5367ff3f430eef052774f78468852f7b9cb39f8a3c"
    static let calamari = "4ac80c99289841dd946ef92765bf659a307d39189b3ce374a92b5f0415ee17a1"
    static let zeitgeist = "1bf2a2ecb4a868de66ea8610f2ce7c8c43706561b6476031315f6640fe38e060"
    static let ethereum = "eip155:1"
    static let rococo = "a84b46a3e602245284bb9a72c4abd58ee979aa7a5d7f8c4dfdddfaaf0665a4ae"
    static let westend = "e143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e"
    static let westmint = "67f9723393ef76214df0118c34bbbd3dbebc8ed46a10973a8c969d48fe7598c9"
    static let hydra = "afdc188f45c71dacbaa0b62e16a91f726c7b8699a9748cdf715459de6b7f366d"
    static let polimec = "7eb9354488318e7549c722669dcbdcdc526f1fef1420e7944667212f3601fdbd"
    static let avail = "b91746b45e0346cc2f815a520b9c6cb4d5c0902af848db0a80f85932d2e8276a"

    static let availTuringTestnet = "d3d2f3a3495dc597434a99d7d449ebad6616db45e4e4f178f31cc6fa14378b70"
    static let vara = "fe1b4c55fd4d668101126434206571a7838a8b6b93a6d1b95d607e78e6c53763"
    static let mythos = "f6ee56e9c5277df5b4ce6ae9983ee88f3cbed27d31beeb98f9f84f997a1ab0b9"

    static var kiltOnEnviroment: String {
        #if F_DEV
            Self.kiltPelegrine
        #else
            Self.kiltSpiritnet
        #endif
    }
}
