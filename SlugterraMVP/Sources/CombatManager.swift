import Foundation

class CombatManager {
    var health: Int = 100
    
    // Meters out of 10
    var fireMeter: Int = 0
    var waterMeter: Int = 0
    var plantMeter: Int = 0
    var electricMeter: Int = 0
    var earthMeter: Int = 0
    
    func processMatches(chains: Set<Chain>) {
        for chain in chains {
            let type = chain.firstTile().tileType
            let amount = chain.length
            
            switch type {
            case .fire: fireMeter += amount
            case .water: waterMeter += amount
            case .plant: plantMeter += amount
            case .electric: electricMeter += amount
            case .earth: earthMeter += amount
            }
        }
    }
    
    func getStatus() -> String {
        return "HP:\(health) | F:\(fireMeter) W:\(waterMeter) P:\(plantMeter) E:\(electricMeter) Ea:\(earthMeter)"
    }
}
