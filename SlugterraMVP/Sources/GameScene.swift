import SpriteKit
import GameplayKit

class GameScene: SKScene {
    
    var board: Board!
    
    let TileWidth: CGFloat = 40.0
    let TileHeight: CGFloat = 40.0
    
    let gameLayer = SKNode()
    let tilesLayer = SKNode()
    
    private var swipeFromColumn: Int?
    private var swipeFromRow: Int?
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder) is not used in this app")
    }
    
    override init(size: CGSize) {
        super.init(size: size)
        
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        let background = SKSpriteNode(color: .darkGray, size: size)
        background.zPosition = -1
        addChild(background)
        
        addChild(gameLayer)
        
        let layerPosition = CGPoint(
            x: -TileWidth * CGFloat(7) / 2,
            y: -TileHeight * CGFloat(7) / 2)
        
        tilesLayer.position = layerPosition
        gameLayer.addChild(tilesLayer)
    }
    
    override func didMove(to view: SKView) {
        board = Board(columns: 7, rows: 7)
        let newTiles = board.initialFill()
        addSprites(for: newTiles)
    }
    
    func addSprites(for tiles: Set<Tile>) {
        for tile in tiles {
            let sprite = SKSpriteNode(color: colorForType(tile.tileType), size: CGSize(width: TileWidth-2, height: TileHeight-2))
            sprite.position = pointFor(column: tile.column, row: tile.row)
            tilesLayer.addChild(sprite)
            tile.sprite = sprite
        }
    }
    
    func pointFor(column: Int, row: Int) -> CGPoint {
        return CGPoint(
            x: CGFloat(column) * TileWidth + TileWidth / 2,
            y: CGFloat(row) * TileHeight + TileHeight / 2)
    }
    
    func colorForType(_ type: TileType) -> UIColor {
        switch type {
        case .fire: return .red
        case .water: return .blue
        case .plant: return .green
        case .electric: return .yellow
        case .earth: return .brown
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: tilesLayer)
        let (success, column, row) = convertPoint(location)
        if success {
            if let tile = board.tileAt(column: column, row: row) {
                swipeFromColumn = column
                swipeFromRow = row
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard swipeFromColumn != nil else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: tilesLayer)
        let (success, column, row) = convertPoint(location)
        if success {
            var horizDelta = 0, vertDelta = 0
            if column < swipeFromColumn! { horizDelta = -1 }
            else if column > swipeFromColumn! { horizDelta = 1 }
            else if row < swipeFromRow! { vertDelta = -1 }
            else if row > swipeFromRow! { vertDelta = 1 }
            
            if horizDelta != 0 || vertDelta != 0 {
                trySwap(horizDelta: horizDelta, vertDelta: vertDelta)
                swipeFromColumn = nil
            }
        }
    }
    
    func trySwap(horizDelta: Int, vertDelta: Int) {
        let toColumn = swipeFromColumn! + horizDelta
        let toRow = swipeFromRow! + vertDelta
        
        guard toColumn >= 0 && toColumn < board.columns else { return }
        guard toRow >= 0 && toRow < board.rows else { return }
        
        if let toTile = board.tileAt(column: toColumn, row: toRow),
           let fromTile = board.tileAt(column: swipeFromColumn!, row: swipeFromRow!) {
            
            board.swapTiles(fromTile, toTile)
            
            // Animate
            let fromSprite = fromTile.sprite as! SKSpriteNode
            let toSprite = toTile.sprite as! SKSpriteNode
            
            fromSprite.run(SKAction.move(to: pointFor(column: fromTile.column, row: fromTile.row), duration: 0.3))
            toSprite.run(SKAction.move(to: pointFor(column: toTile.column, row: toTile.row), duration: 0.3))
        }
    }
    
    func convertPoint(_ point: CGPoint) -> (success: Bool, column: Int, row: Int) {
        if point.x >= 0 && point.x < CGFloat(board.columns) * TileWidth &&
           point.y >= 0 && point.y < CGFloat(board.rows) * TileHeight {
            return (true, Int(point.x / TileWidth), Int(point.y / TileHeight))
        } else {
            return (false, 0, 0)
        }
    }
}
