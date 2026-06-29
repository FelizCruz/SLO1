import Foundation

class Board {
    let columns: Int
    let rows: Int
    private var tiles: Array2D<Tile>
    
    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        self.tiles = Array2D<Tile>(columns: columns, rows: rows)
    }
    
    func tileAt(column: Int, row: Int) -> Tile? {
        assert(column >= 0 && column < columns)
        assert(row >= 0 && row < rows)
        return tiles[column, row]
    }
    
    func initialFill() -> Set<Tile> {
        var set = Set<Tile>()
        for row in 0..<rows {
            for column in 0..<columns {
                var tileType: TileType
                repeat {
                    tileType = TileType.allCases.randomElement()!
                } while (column >= 2 && tiles[column - 1, row]?.tileType == tileType && tiles[column - 2, row]?.tileType == tileType)
                       || (row >= 2 && tiles[column, row - 1]?.tileType == tileType && tiles[column, row - 2]?.tileType == tileType)
                
                let tile = Tile(column: column, row: row, tileType: tileType)
                tiles[column, row] = tile
                set.insert(tile)
            }
        }
        return set
    }

    func swapTiles(_ tileA: Tile, _ tileB: Tile) {
        tiles[tileA.column, tileA.row] = tileB
        tiles[tileB.column, tileB.row] = tileA
        
        let tempCol = tileA.column
        let tempRow = tileA.row
        tileA.column = tileB.column
        tileA.row = tileB.row
        tileB.column = tempCol
        tileB.row = tempRow
    }
}
