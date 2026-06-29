import SpriteKit
import GameplayKit

class GameScene: SKScene {
    
    var board: Board!
    var combatManager: CombatManager!
    
    let TileWidth: CGFloat = 40.0
    let TileHeight: CGFloat = 40.0
    
    let gameLayer = SKNode()
    let tilesLayer = SKNode()
    
    let hudLabel = SKLabelNode(fontNamed: "Courier-Bold")
    
    private var swipeFromColumn: Int?
    private var swipeFromRow: Int?
    
    var userInteractionEnabledLocal = true
    
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
        
        // Position the HUD just above the grid, guaranteed to be visible
        hudLabel.position = CGPoint(x: 0, y: (TileHeight * CGFloat(7)) / 2 + 50)
        hudLabel.zPosition = 1000 // Bring to absolute front
        hudLabel.fontSize = 20
        hudLabel.fontColor = .white
        addChild(hudLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder) is not used in this app")
    }
    
    override func didMove(to view: SKView) {
        board = Board(columns: 7, rows: 7)
        combatManager = CombatManager()
        updateHUD()
        
        let newTiles = board.initialFill()
        addSprites(for: newTiles)
    }
    
    func updateHUD() {
        hudLabel.text = combatManager.getStatus()
    }
    
    func addSprites(for tiles: Set<Tile>) {
        for tile in tiles {
            let sprite = SKSpriteNode(texture: textureForType(tile.tileType))
            sprite.size = CGSize(width: TileWidth - 2, height: TileHeight - 2)
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
    
    func textureForType(_ type: TileType) -> SKTexture {
        switch type {
        case .fire: return SKTexture(imageNamed: "fire_tile")
        case .water: return SKTexture(imageNamed: "water_tile")
        case .plant: return SKTexture(imageNamed: "plant_tile")
        case .electric: return SKTexture(imageNamed: "electric_tile")
        case .earth: return SKTexture(imageNamed: "earth_tile")
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard userInteractionEnabledLocal else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: tilesLayer)
        let (success, column, row) = convertPoint(location)
        if success {
            if let _ = board.tileAt(column: column, row: row) {
                swipeFromColumn = column
                swipeFromRow = row
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard userInteractionEnabledLocal else { return }
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
            
            let swap = Swap(tileA: fromTile, tileB: toTile)
            
            userInteractionEnabledLocal = false
            
            if board.isPossibleSwap(swap) {
                board.swapTiles(swap)
                animateSwap(swap, completion: {
                    self.handleMatches()
                })
            } else {
                animateInvalidSwap(swap, completion: {
                    self.userInteractionEnabledLocal = true
                })
            }
        }
    }
    
    func animateSwap(_ swap: Swap, completion: @escaping () -> Void) {
        let spriteA = swap.tileA.sprite as! SKSpriteNode
        let spriteB = swap.tileB.sprite as! SKSpriteNode
        
        spriteA.zPosition = 100
        spriteB.zPosition = 90
        
        let Duration: TimeInterval = 0.3
        
        let moveA = SKAction.move(to: spriteB.position, duration: Duration)
        moveA.timingMode = .easeOut
        spriteA.run(moveA, completion: completion)
        
        let moveB = SKAction.move(to: spriteA.position, duration: Duration)
        moveB.timingMode = .easeOut
        spriteB.run(moveB)
    }
    
    func animateInvalidSwap(_ swap: Swap, completion: @escaping () -> Void) {
        let spriteA = swap.tileA.sprite as! SKSpriteNode
        let spriteB = swap.tileB.sprite as! SKSpriteNode
        
        spriteA.zPosition = 100
        spriteB.zPosition = 90
        
        let Duration: TimeInterval = 0.2
        
        let moveA = SKAction.move(to: spriteB.position, duration: Duration)
        moveA.timingMode = .easeOut
        
        let moveB = SKAction.move(to: spriteA.position, duration: Duration)
        moveB.timingMode = .easeOut
        
        spriteA.run(SKAction.sequence([moveA, moveB]), completion: completion)
        spriteB.run(SKAction.sequence([moveB, moveA]))
    }
    
    func handleMatches() {
        let chains = board.removeMatches()
        
        if chains.count == 0 {
            beginNextTurn()
            return
        }
        
        combatManager.processMatches(chains: chains)
        updateHUD()
        
        animateMatchedTiles(for: chains) {
            let columns = self.board.fillHoles()
            self.animateFallingTiles(in: columns) {
                let newColumns = self.board.topUpTiles()
                self.animateNewTiles(in: newColumns) {
                    self.handleMatches() // Recursively check for combos
                }
            }
        }
    }
    
    func animateMatchedTiles(for chains: Set<Chain>, completion: @escaping () -> Void) {
        for chain in chains {
            for tile in chain.tiles {
                if let sprite = tile.sprite as? SKSpriteNode {
                    if sprite.action(forKey: "removing") == nil {
                        let scaleAction = SKAction.scale(to: 0.1, duration: 0.3)
                        scaleAction.timingMode = .easeOut
                        sprite.run(SKAction.sequence([scaleAction, SKAction.removeFromParent()]), withKey: "removing")
                    }
                }
            }
        }
        run(SKAction.wait(forDuration: 0.3), completion: completion)
    }
    
    func animateFallingTiles(in columns: [[Tile]], completion: @escaping () -> Void) {
        var longestDuration: TimeInterval = 0
        for array in columns {
            for (idx, tile) in array.enumerated() {
                let newPosition = pointFor(column: tile.column, row: tile.row)
                let delay = 0.05 + 0.15 * TimeInterval(idx)
                let sprite = tile.sprite as! SKSpriteNode
                let duration = TimeInterval(((sprite.position.y - newPosition.y) / TileHeight) * 0.1)
                
                longestDuration = max(longestDuration, duration + delay)
                
                let moveAction = SKAction.move(to: newPosition, duration: duration)
                moveAction.timingMode = .easeOut
                sprite.run(SKAction.sequence([SKAction.wait(forDuration: delay), SKAction.group([moveAction])]))
            }
        }
        run(SKAction.wait(forDuration: longestDuration), completion: completion)
    }
    
    func animateNewTiles(in columns: [[Tile]], completion: @escaping () -> Void) {
        var longestDuration: TimeInterval = 0
        
        for array in columns {
            let startRow = array[0].row + 1
            for (idx, tile) in array.enumerated() {
                let sprite = SKSpriteNode(texture: textureForType(tile.tileType))
                sprite.size = CGSize(width: TileWidth - 2, height: TileHeight - 2)
                sprite.position = pointFor(column: tile.column, row: startRow)
                tilesLayer.addChild(sprite)
                tile.sprite = sprite
                
                let delay = 0.1 + 0.2 * TimeInterval(array.count - 1 - idx)
                let duration = TimeInterval(startRow - tile.row) * 0.1
                longestDuration = max(longestDuration, duration + delay)
                
                let newPosition = pointFor(column: tile.column, row: tile.row)
                let moveAction = SKAction.move(to: newPosition, duration: duration)
                moveAction.timingMode = .easeOut
                sprite.alpha = 0
                sprite.run(SKAction.sequence([
                    SKAction.wait(forDuration: delay),
                    SKAction.group([SKAction.fadeIn(withDuration: 0.05), moveAction])
                ]))
            }
        }
        run(SKAction.wait(forDuration: longestDuration), completion: completion)
    }
    
    func beginNextTurn() {
        userInteractionEnabledLocal = true
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
