import Foundation

enum TileType: Int, CaseIterable {
    case fire = 1
    case water = 2
    case plant = 3
    case electric = 4
    case earth = 5
    
    static func random() -> TileType {
        return allCases.randomElement()!
    }
}

class Tile: Hashable {
    var column: Int
    var row: Int
    let tileType: TileType
    var sprite: AnyObject? // Holds SKSpriteNode
    
    init(column: Int, row: Int, tileType: TileType) {
        self.column = column
        self.row = row
        self.tileType = tileType
    }
    
    static func == (lhs: Tile, rhs: Tile) -> Bool {
        return lhs.column == rhs.column && lhs.row == rhs.row
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(column)
        hasher.combine(row)
    }
}

struct Array2D<T> {
    let columns: Int
    let rows: Int
    private var array: [T?]
    
    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        array = Array<T?>(repeating: nil, count: rows * columns)
    }
    
    subscript(column: Int, row: Int) -> T? {
        get { return array[row * columns + column] }
        set { array[row * columns + column] = newValue }
    }
}
