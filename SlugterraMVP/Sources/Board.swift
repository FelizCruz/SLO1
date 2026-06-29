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
        return createInitialTiles()
    }
    
    private func createInitialTiles() -> Set<Tile> {
        var set = Set<Tile>()
        for row in 0..<rows {
            for column in 0..<columns {
                var tileType: TileType
                repeat {
                    tileType = TileType.random()
                } while (column >= 2 && tiles[column - 1, row]?.tileType == tileType && tiles[column - 2, row]?.tileType == tileType)
                     || (row >= 2 && tiles[column, row - 1]?.tileType == tileType && tiles[column, row - 2]?.tileType == tileType)
                
                let tile = Tile(column: column, row: row, tileType: tileType)
                tiles[column, row] = tile
                set.insert(tile)
            }
        }
        return set
    }
    
    func swapTiles(_ swap: Swap) {
        let tileA = swap.tileA
        let tileB = swap.tileB
        
        let columnA = tileA.column, rowA = tileA.row
        let columnB = tileB.column, rowB = tileB.row
        
        tiles[columnA, rowA] = tileB
        tiles[columnB, rowB] = tileA
        
        tileA.column = columnB
        tileA.row = rowB
        tileB.column = columnA
        tileB.row = rowA
    }
    
    func isPossibleSwap(_ swap: Swap) -> Bool {
        return hasChain(atColumn: swap.tileA.column, row: swap.tileA.row, type: swap.tileB.tileType) ||
               hasChain(atColumn: swap.tileB.column, row: swap.tileB.row, type: swap.tileA.tileType)
    }
    
    private func hasChain(atColumn column: Int, row: Int, type: TileType) -> Bool {
        var horzLength = 1
        var idx = column - 1
        while idx >= 0 && tiles[idx, row]?.tileType == type {
            idx -= 1
            horzLength += 1
        }
        idx = column + 1
        while idx < columns && tiles[idx, row]?.tileType == type {
            idx += 1
            horzLength += 1
        }
        if horzLength >= 3 { return true }
        
        var vertLength = 1
        idx = row - 1
        while idx >= 0 && tiles[column, idx]?.tileType == type {
            idx -= 1
            vertLength += 1
        }
        idx = row + 1
        while idx < rows && tiles[column, idx]?.tileType == type {
            idx += 1
            vertLength += 1
        }
        return vertLength >= 3
    }
    
    func removeMatches() -> Set<Chain> {
        let horizontalChains = detectHorizontalMatches()
        let verticalChains = detectVerticalMatches()
        
        removeTiles(in: horizontalChains)
        removeTiles(in: verticalChains)
        
        return horizontalChains.union(verticalChains)
    }
    
    private func detectHorizontalMatches() -> Set<Chain> {
        var set = Set<Chain>()
        for row in 0..<rows {
            var column = 0
            while column < columns - 2 {
                if let tile = tiles[column, row] {
                    let matchType = tile.tileType
                    if tiles[column + 1, row]?.tileType == matchType && tiles[column + 2, row]?.tileType == matchType {
                        let chain = Chain(chainType: .horizontal)
                        repeat {
                            chain.add(tile: tiles[column, row]!)
                            column += 1
                        } while column < columns && tiles[column, row]?.tileType == matchType
                        set.insert(chain)
                        continue
                    }
                }
                column += 1
            }
        }
        return set
    }
    
    private func detectVerticalMatches() -> Set<Chain> {
        var set = Set<Chain>()
        for column in 0..<columns {
            var row = 0
            while row < rows - 2 {
                if let tile = tiles[column, row] {
                    let matchType = tile.tileType
                    if tiles[column, row + 1]?.tileType == matchType && tiles[column, row + 2]?.tileType == matchType {
                        let chain = Chain(chainType: .vertical)
                        repeat {
                            chain.add(tile: tiles[column, row]!)
                            row += 1
                        } while row < rows && tiles[column, row]?.tileType == matchType
                        set.insert(chain)
                        continue
                    }
                }
                row += 1
            }
        }
        return set
    }
    
    private func removeTiles(in chains: Set<Chain>) {
        for chain in chains {
            for tile in chain.tiles {
                tiles[tile.column, tile.row] = nil
            }
        }
    }
    
    func fillHoles() -> [[Tile]] {
        var columnsArray = [[Tile]]()
        for column in 0..<columns {
            var array = [Tile]()
            for row in 0..<rows {
                if tiles[column, row] == nil {
                    for lookup in (row + 1)..<rows {
                        if let tile = tiles[column, lookup] {
                            tiles[column, lookup] = nil
                            tiles[column, row] = tile
                            tile.row = row
                            array.append(tile)
                            break
                        }
                    }
                }
            }
            if !array.isEmpty { columnsArray.append(array) }
        }
        return columnsArray
    }
    
    func topUpTiles() -> [[Tile]] {
        var columnsArray = [[Tile]]()
        var tileType: TileType = .fire
        for column in 0..<columns {
            var array = [Tile]()
            var row = rows - 1
            while row >= 0 && tiles[column, row] == nil {
                var newTileType: TileType
                repeat {
                    newTileType = TileType.random()
                } while newTileType == tileType
                tileType = newTileType
                let tile = Tile(column: column, row: row, tileType: tileType)
                tiles[column, row] = tile
                array.append(tile)
                row -= 1
            }
            if !array.isEmpty { columnsArray.append(array) }
        }
        return columnsArray
    }
}
