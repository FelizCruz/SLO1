import Foundation

enum ChainType: CustomStringConvertible {
    case horizontal
    case vertical
    
    var description: String {
        switch self {
        case .horizontal: return "Horizontal"
        case .vertical: return "Vertical"
        }
    }
}

class Chain: Hashable, CustomStringConvertible {
    var tiles: [Tile] = []
    var chainType: ChainType
    
    init(chainType: ChainType) {
        self.chainType = chainType
    }
    
    func add(tile: Tile) {
        tiles.append(tile)
    }
    
    func firstTile() -> Tile {
        return tiles[0]
    }
    
    func lastTile() -> Tile {
        return tiles[tiles.count - 1]
    }
    
    var length: Int {
        return tiles.count
    }
    
    var description: String {
        return "type:\(chainType) tiles:\(tiles)"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(tiles[0].hashValue)
    }
    
    static func ==(lhs: Chain, rhs: Chain) -> Bool {
        return lhs.tiles == rhs.tiles
    }
}
