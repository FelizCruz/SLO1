import Foundation

struct Swap: CustomStringConvertible, Hashable {
    let tileA: Tile
    let tileB: Tile
    
    init(tileA: Tile, tileB: Tile) {
        self.tileA = tileA
        self.tileB = tileB
    }
    
    var description: String {
        return "swap \(tileA) with \(tileB)"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(tileA.hashValue ^ tileB.hashValue)
    }
    
    static func ==(lhs: Swap, rhs: Swap) -> Bool {
        return (lhs.tileA == rhs.tileA && lhs.tileB == rhs.tileB) ||
               (lhs.tileB == rhs.tileA && lhs.tileA == rhs.tileB)
    }
}
