import AppKit
import SceneKit
import SpriteKit
import CoreGraphics

// MARK: - Vector Math
extension SCNVector3 {
    static func + (a: SCNVector3, b: SCNVector3) -> SCNVector3 { SCNVector3(a.x+b.x, a.y+b.y, a.z+b.z) }
    static func - (a: SCNVector3, b: SCNVector3) -> SCNVector3 { SCNVector3(a.x-b.x, a.y-b.y, a.z-b.z) }
    static func * (v: SCNVector3, s: CGFloat) -> SCNVector3 { SCNVector3(v.x*s, v.y*s, v.z*s) }
    var len: CGFloat { sqrt(x*x + y*y + z*z) }
    var flat: CGFloat { sqrt(x*x + z*z) }
    var norm: SCNVector3 { let l = len; guard l > 0.001 else { return SCNVector3(0,0,0) }; return SCNVector3(x/l, y/l, z/l) }
    var flatNorm: SCNVector3 { let l = flat; guard l > 0.001 else { return SCNVector3(0,0,-1) }; return SCNVector3(x/l, 0, z/l) }
}
func lp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a+(b-a)*t }
func rF(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { CGFloat.random(in: lo...hi) }
func rI(_ lo: Int, _ hi: Int) -> Int { Int.random(in: lo...hi) }

// MARK: - Constants
let WIN_W: CGFloat = 1280
let WIN_H: CGFloat = 720
let TILE: CGFloat = 2.0
let GRID_W = 42
let GRID_H = 42
let WALL_H: CGFloat = 4.0
let P_SPEED: CGFloat = 9.0
let P_ATK_RANGE: CGFloat = 2.8
let P_ATK_ARC: CGFloat = CGFloat.pi * 0.7
let P_ATK_CD: CGFloat = 0.35
let P_DASH_DUR: CGFloat = 0.18
let P_DASH_CD: CGFloat = 0.55
let P_DASH_SPD: CGFloat = 28.0
let KNOCKBACK: CGFloat = 8.0
let CAM_HEIGHT: CGFloat = 1.6
let MOUSE_SENS_X: CGFloat = 0.003
let MOUSE_SENS_Y: CGFloat = 0.003
let PITCH_LIMIT: CGFloat = 1.3
let FOG_START: CGFloat = 15.0
let FOG_END: CGFloat = 35.0

// XP table
let XP_VALUES: [Int] = [15, 25, 20, 35, 45, 60] // per enemy type

// MARK: - Colors
let cCyan = NSColor(red: 0, green: 0.85, blue: 1, alpha: 1)
let cRed = NSColor(red: 1, green: 0.15, blue: 0.1, alpha: 1)
let cGreen = NSColor(red: 0.2, green: 0.9, blue: 0.2, alpha: 1)
let cGold = NSColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
let cPurple = NSColor(red: 0.6, green: 0.15, blue: 0.9, alpha: 1)
let cOrange = NSColor(red: 1, green: 0.5, blue: 0.1, alpha: 1)
let cFloor1 = NSColor(red: 0.18, green: 0.16, blue: 0.14, alpha: 1)
let cFloor2 = NSColor(red: 0.15, green: 0.13, blue: 0.11, alpha: 1)
let cWall = NSColor(red: 0.28, green: 0.24, blue: 0.22, alpha: 1)
let cWallDk = NSColor(red: 0.2, green: 0.17, blue: 0.15, alpha: 1)

func mm(_ c: NSColor, e: NSColor? = nil, con: Bool = false) -> SCNMaterial {
    let m = SCNMaterial(); m.diffuse.contents = c
    if let em = e { m.emission.contents = em }
    if con { m.lightingModel = .constant }; return m
}

// MARK: - Room
struct Room { let x, y, w, h: Int; var cx: Int { x+w/2 }; var cy: Int { y+h/2 } }

// MARK: - Card System
enum CardCategory { case weapon, upgrade, buff }
struct Card {
    let id: Int; let name: String; let desc: String; let category: CardCategory
}
let ALL_CARDS: [Card] = [
    Card(id: 1,  name: "BROADSWORD",    desc: "+35% Damage, -15% Speed",    category: .weapon),
    Card(id: 2,  name: "TWIN DAGGERS",  desc: "+40% Atk Speed, -15% Dmg",   category: .weapon),
    Card(id: 3,  name: "WAR HAMMER",    desc: "+50% Dmg, +KB, -25% Speed",  category: .weapon),
    Card(id: 4,  name: "IRON HIDE",     desc: "+30 Max HP, Heal 30",         category: .upgrade),
    Card(id: 5,  name: "KEEN EDGE",     desc: "+20% Damage",                 category: .upgrade),
    Card(id: 6,  name: "QUICK HANDS",   desc: "+25% Attack Speed",           category: .upgrade),
    Card(id: 7,  name: "FLEET FOOT",    desc: "+20% Move Speed",             category: .upgrade),
    Card(id: 8,  name: "LONG ARMS",     desc: "+25% Attack Range",           category: .upgrade),
    Card(id: 9,  name: "VAMPIRIC",      desc: "+8% Lifesteal",               category: .buff),
    Card(id: 10, name: "SECOND WIND",   desc: "Full Heal",                   category: .buff),
    Card(id: 11, name: "SHIELD ORB",    desc: "+40 Shield HP",               category: .buff),
    Card(id: 12, name: "REGENERATION",  desc: "+2 HP/sec",                   category: .buff),
]

// MARK: - Dungeon Generator
func generateDungeon(floor: Int) -> ([[Int]], [Room]) {
    var grid = Array(repeating: Array(repeating: 0, count: GRID_W), count: GRID_H)
    var rooms: [Room] = []
    let target = min(12, 6 + floor)
    for _ in 0..<target * 6 {
        if rooms.count >= target { break }
        let w = rI(5, 9), h = rI(5, 9)
        let x = rI(2, GRID_W - w - 2), y = rI(2, GRID_H - h - 2)
        var ok = true
        for r in rooms {
            if x < r.x+r.w+2 && x+w+2 > r.x && y < r.y+r.h+2 && y+h+2 > r.y { ok = false; break }
        }
        if !ok { continue }
        for ry in y..<y+h { for rx in x..<x+w { grid[ry][rx] = 1 } }
        rooms.append(Room(x: x, y: y, w: w, h: h))
    }
    // Connect rooms with L-shaped corridors
    for i in 0..<rooms.count-1 {
        var cx = rooms[i].cx, cy = rooms[i].cy
        let tx = rooms[i+1].cx, ty = rooms[i+1].cy
        while cx != tx { grid[cy][cx] = 1; cx += cx < tx ? 1 : -1 }
        while cy != ty { grid[cy][cx] = 1; cy += cy < ty ? 1 : -1 }
        grid[cy][cx] = 1
    }
    // Widen corridors
    let snap = grid
    for y in 1..<GRID_H-1 {
        for x in 1..<GRID_W-1 {
            if snap[y][x] == 1 {
                if grid[y+1][x] == 0 && snap[y-1][x] == 1 { grid[y+1][x] = 1 }
                if grid[y][x+1] == 0 && snap[y][x-1] == 1 { grid[y][x+1] = 1 }
            }
        }
    }
    return (grid, rooms)
}

// MARK: - Dungeon Renderer (First Person - taller walls, ceiling)
func renderDungeon(grid: [[Int]]) -> SCNNode {
    let root = SCNNode()
    let floorGeo = SCNBox(width: TILE, height: 0.1, length: TILE, chamferRadius: 0)
    let wallGeo = SCNBox(width: TILE, height: WALL_H, length: TILE, chamferRadius: 0)
    let ceilGeo = SCNBox(width: TILE, height: 0.1, length: TILE, chamferRadius: 0)
    let floorMat1 = mm(cFloor1); let floorMat2 = mm(cFloor2)
    let wallMat = mm(cWall); let wallTopMat = mm(cWallDk)
    let ceilMat = mm(NSColor(red: 0.1, green: 0.09, blue: 0.08, alpha: 1))
    wallGeo.materials = [wallMat, wallMat, wallTopMat, wallMat, wallMat, wallMat]
    for y in 0..<GRID_H {
        for x in 0..<GRID_W {
            let wx = CGFloat(x) * TILE
            let wz = CGFloat(y) * TILE
            if grid[y][x] == 1 {
                // Floor tile
                let f = SCNNode(geometry: floorGeo)
                f.geometry!.materials = [(x+y) % 2 == 0 ? floorMat1 : floorMat2]
                f.position = SCNVector3(wx, CGFloat(-0.05), wz)
                root.addChildNode(f)
                // Ceiling tile
                let c = SCNNode(geometry: ceilGeo)
                c.geometry!.materials = [ceilMat]
                c.position = SCNVector3(wx, WALL_H, wz)
                root.addChildNode(c)
            } else {
                // Wall cubes adjacent to floor
                var adj = false
                for (ddx, ddy) in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,-1),(-1,1),(1,1)] {
                    let nx = x+ddx, ny = y+ddy
                    if nx >= 0 && nx < GRID_W && ny >= 0 && ny < GRID_H && grid[ny][nx] == 1 { adj = true; break }
                }
                if adj {
                    let w = SCNNode(geometry: wallGeo)
                    w.position = SCNVector3(wx, WALL_H / CGFloat(2.0), wz)
                    root.addChildNode(w)
                }
            }
        }
    }
    return root
}

// MARK: - Enemy Builders (6 types)
func buildEnemy(type: Int) -> SCNNode {
    let root = SCNNode()
    switch type {
    case 0: // Slime - green sphere
        let body = SCNNode(geometry: SCNSphere(radius: 0.55))
        body.geometry!.materials = [mm(NSColor(red: 0.15, green: 0.6, blue: 0.15, alpha: 0.85),
                                       e: NSColor(red: 0.05, green: 0.2, blue: 0.05, alpha: 1))]
        body.position = SCNVector3(CGFloat(0), CGFloat(0.45), CGFloat(0))
        body.scale = SCNVector3(CGFloat(1), CGFloat(0.7), CGFloat(1))
        root.addChildNode(body)
        let eye1 = SCNNode(geometry: SCNSphere(radius: 0.08))
        eye1.geometry!.materials = [mm(.white, e: .white, con: true)]
        eye1.position = SCNVector3(CGFloat(-0.15), CGFloat(0.55), CGFloat(-0.35)); root.addChildNode(eye1)
        let eye2 = SCNNode(geometry: SCNSphere(radius: 0.08))
        eye2.geometry!.materials = [mm(.white, e: .white, con: true)]
        eye2.position = SCNVector3(CGFloat(0.15), CGFloat(0.55), CGFloat(-0.35)); root.addChildNode(eye2)
        let squish = SCNAction.sequence([
            SCNAction.scale(to: 0.9, duration: 0.5),
            SCNAction.scale(to: 1.1, duration: 0.5)])
        root.runAction(SCNAction.repeatForever(squish))

    case 1: // Skeleton - bone humanoid with sword
        let torso = SCNNode(geometry: SCNBox(width: 0.4, height: 0.7, length: 0.25, chamferRadius: 0.03))
        torso.geometry!.materials = [mm(NSColor(red: 0.85, green: 0.8, blue: 0.7, alpha: 1))]
        torso.position = SCNVector3(CGFloat(0), CGFloat(0.9), CGFloat(0)); root.addChildNode(torso)
        let skull = SCNNode(geometry: SCNSphere(radius: 0.2))
        skull.geometry!.materials = [mm(NSColor(red: 0.9, green: 0.85, blue: 0.75, alpha: 1))]
        skull.position = SCNVector3(CGFloat(0), CGFloat(1.4), CGFloat(0)); root.addChildNode(skull)
        for s: CGFloat in [-1, 1] {
            let e = SCNNode(geometry: SCNSphere(radius: 0.04))
            e.geometry!.materials = [mm(cRed, e: cRed, con: true)]
            e.position = SCNVector3(s * CGFloat(0.08), CGFloat(1.42), CGFloat(-0.16)); root.addChildNode(e)
        }
        for s: CGFloat in [-1, 1] {
            let l = SCNNode(geometry: SCNCylinder(radius: 0.06, height: 0.5))
            l.geometry!.materials = [mm(NSColor(red: 0.85, green: 0.8, blue: 0.7, alpha: 1))]
            l.position = SCNVector3(s * CGFloat(0.12), CGFloat(0.3), CGFloat(0)); root.addChildNode(l)
        }
        let sw = SCNNode(geometry: SCNBox(width: 0.05, height: 0.05, length: 1.1, chamferRadius: 0.01))
        sw.geometry!.materials = [mm(NSColor(white: 0.6, alpha: 1))]
        sw.position = SCNVector3(CGFloat(0.35), CGFloat(0.9), CGFloat(-0.5)); root.addChildNode(sw)

    case 2: // Bat - purple sphere that flies
        let body = SCNNode(geometry: SCNSphere(radius: 0.35))
        body.geometry!.materials = [mm(NSColor(red: 0.4, green: 0.1, blue: 0.5, alpha: 0.9),
                                       e: NSColor(red: 0.15, green: 0.0, blue: 0.2, alpha: 1))]
        body.position = SCNVector3(CGFloat(0), CGFloat(2.0), CGFloat(0)); root.addChildNode(body)
        // Wings
        for s: CGFloat in [-1, 1] {
            let wing = SCNNode(geometry: SCNBox(width: 0.6, height: 0.05, length: 0.4, chamferRadius: 0.02))
            wing.geometry!.materials = [mm(NSColor(red: 0.3, green: 0.05, blue: 0.4, alpha: 0.8))]
            wing.position = SCNVector3(s * CGFloat(0.5), CGFloat(2.0), CGFloat(0)); root.addChildNode(wing)
            wing.runAction(SCNAction.repeatForever(SCNAction.sequence([
                SCNAction.rotateBy(x: 0, y: 0, z: s * CGFloat(0.4), duration: 0.15),
                SCNAction.rotateBy(x: 0, y: 0, z: s * CGFloat(-0.4), duration: 0.15)])))
        }
        let eye1 = SCNNode(geometry: SCNSphere(radius: 0.06))
        eye1.geometry!.materials = [mm(cRed, e: cRed, con: true)]
        eye1.position = SCNVector3(CGFloat(-0.1), CGFloat(2.05), CGFloat(-0.28)); root.addChildNode(eye1)
        let eye2 = SCNNode(geometry: SCNSphere(radius: 0.06))
        eye2.geometry!.materials = [mm(cRed, e: cRed, con: true)]
        eye2.position = SCNVector3(CGFloat(0.1), CGFloat(2.05), CGFloat(-0.28)); root.addChildNode(eye2)
        // Y oscillation
        root.runAction(SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: CGFloat(0.3), z: 0, duration: 0.6),
            SCNAction.moveBy(x: 0, y: CGFloat(-0.3), z: 0, duration: 0.6)])))

    case 3: // Mage - purple cone robe, shoots fireballs
        let robe = SCNNode(geometry: SCNCone(topRadius: 0.15, bottomRadius: 0.45, height: 1.3))
        robe.geometry!.materials = [mm(NSColor(red: 0.25, green: 0.1, blue: 0.35, alpha: 1),
                                       e: NSColor(red: 0.08, green: 0, blue: 0.12, alpha: 1))]
        robe.position = SCNVector3(CGFloat(0), CGFloat(0.65), CGFloat(0)); root.addChildNode(robe)
        let head = SCNNode(geometry: SCNSphere(radius: 0.18))
        head.geometry!.materials = [mm(NSColor(red: 0.15, green: 0.05, blue: 0.2, alpha: 1))]
        head.position = SCNVector3(CGFloat(0), CGFloat(1.45), CGFloat(0)); root.addChildNode(head)
        for s: CGFloat in [-1, 1] {
            let e = SCNNode(geometry: SCNSphere(radius: 0.04))
            e.geometry!.materials = [mm(cPurple, e: cPurple, con: true)]
            e.position = SCNVector3(s * CGFloat(0.07), CGFloat(1.48), CGFloat(-0.14)); root.addChildNode(e)
        }
        let hat = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.22, height: 0.5))
        hat.geometry!.materials = [mm(NSColor(red: 0.2, green: 0.08, blue: 0.3, alpha: 1))]
        hat.position = SCNVector3(CGFloat(0), CGFloat(1.8), CGFloat(0)); root.addChildNode(hat)
        let orb = SCNNode(geometry: SCNSphere(radius: 0.12))
        orb.geometry!.materials = [mm(cPurple, e: cPurple, con: true)]
        orb.position = SCNVector3(CGFloat(0.4), CGFloat(1.3), CGFloat(-0.3)); orb.name = "orb"
        orb.runAction(SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: CGFloat(0.15), z: 0, duration: 0.8),
            SCNAction.moveBy(x: 0, y: CGFloat(-0.15), z: 0, duration: 0.8)])))
        root.addChildNode(orb)

    case 4: // Knight - dark armored humanoid
        let torso = SCNNode(geometry: SCNBox(width: 0.55, height: 0.85, length: 0.35, chamferRadius: 0.04))
        torso.geometry!.materials = [mm(NSColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1),
                                        e: NSColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1))]
        torso.position = SCNVector3(CGFloat(0), CGFloat(1.0), CGFloat(0)); root.addChildNode(torso)
        let helmet = SCNNode(geometry: SCNBox(width: 0.35, height: 0.35, length: 0.35, chamferRadius: 0.06))
        helmet.geometry!.materials = [mm(NSColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1))]
        helmet.position = SCNVector3(CGFloat(0), CGFloat(1.65), CGFloat(0)); root.addChildNode(helmet)
        // Visor slit glow
        let visor = SCNNode(geometry: SCNBox(width: 0.25, height: 0.05, length: 0.1, chamferRadius: 0.01))
        visor.geometry!.materials = [mm(cRed, e: cRed, con: true)]
        visor.position = SCNVector3(CGFloat(0), CGFloat(1.68), CGFloat(-0.18)); root.addChildNode(visor)
        for s: CGFloat in [-1, 1] {
            let sh = SCNNode(geometry: SCNBox(width: 0.3, height: 0.2, length: 0.35, chamferRadius: 0.04))
            sh.geometry!.materials = [mm(NSColor(red: 0.13, green: 0.13, blue: 0.16, alpha: 1))]
            sh.position = SCNVector3(s * CGFloat(0.5), CGFloat(1.35), CGFloat(0)); root.addChildNode(sh)
        }
        for s: CGFloat in [-1, 1] {
            let l = SCNNode(geometry: SCNCylinder(radius: 0.1, height: 0.6))
            l.geometry!.materials = [mm(NSColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1))]
            l.position = SCNVector3(s * CGFloat(0.17), CGFloat(0.35), CGFloat(0)); root.addChildNode(l)
        }
        // Big sword
        let blade = SCNNode(geometry: SCNBox(width: 0.08, height: 0.08, length: 1.5, chamferRadius: 0.02))
        blade.geometry!.materials = [mm(NSColor(white: 0.5, alpha: 1), e: NSColor(red: 0.15, green: 0.0, blue: 0.0, alpha: 1))]
        blade.position = SCNVector3(CGFloat(0.45), CGFloat(1.0), CGFloat(-0.7)); root.addChildNode(blade)

    case 5: // Demon - big red tanky
        let body = SCNNode(geometry: SCNCapsule(capRadius: 0.5, height: 1.8))
        body.geometry!.materials = [mm(NSColor(red: 0.6, green: 0.08, blue: 0.05, alpha: 1),
                                       e: NSColor(red: 0.2, green: 0.02, blue: 0.0, alpha: 1))]
        body.position = SCNVector3(CGFloat(0), CGFloat(1.1), CGFloat(0)); root.addChildNode(body)
        let head = SCNNode(geometry: SCNSphere(radius: 0.35))
        head.geometry!.materials = [mm(NSColor(red: 0.5, green: 0.05, blue: 0.03, alpha: 1))]
        head.position = SCNVector3(CGFloat(0), CGFloat(2.2), CGFloat(0)); root.addChildNode(head)
        // Horns
        for s: CGFloat in [-1, 1] {
            let horn = SCNNode(geometry: SCNCone(topRadius: 0.0, bottomRadius: 0.08, height: 0.5))
            horn.geometry!.materials = [mm(NSColor(red: 0.2, green: 0.05, blue: 0.0, alpha: 1))]
            horn.position = SCNVector3(s * CGFloat(0.25), CGFloat(2.5), CGFloat(-0.1))
            horn.eulerAngles.z = s * CGFloat(-0.4)
            root.addChildNode(horn)
        }
        // Glowing eyes
        for s: CGFloat in [-1, 1] {
            let e = SCNNode(geometry: SCNSphere(radius: 0.06))
            e.geometry!.materials = [mm(cOrange, e: cOrange, con: true)]
            e.position = SCNVector3(s * CGFloat(0.12), CGFloat(2.25), CGFloat(-0.28)); root.addChildNode(e)
        }
        // Scale up
        root.scale = SCNVector3(CGFloat(1.3), CGFloat(1.3), CGFloat(1.3))
    default: break
    }
    return root
}

// MARK: - Item Builders
func buildPotion() -> SCNNode {
    let n = SCNNode()
    let body = SCNNode(geometry: SCNCylinder(radius: 0.15, height: 0.3))
    body.geometry!.materials = [mm(NSColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 0.8), e: cRed)]
    body.position = SCNVector3(CGFloat(0), CGFloat(0.25), CGFloat(0)); n.addChildNode(body)
    let top = SCNNode(geometry: SCNSphere(radius: 0.12))
    top.geometry!.materials = [mm(cRed, e: cRed, con: true)]
    top.position = SCNVector3(CGFloat(0), CGFloat(0.45), CGFloat(0)); n.addChildNode(top)
    n.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi*2, z: 0, duration: 3)))
    n.runAction(SCNAction.repeatForever(SCNAction.sequence([
        SCNAction.moveBy(x: 0, y: CGFloat(0.15), z: 0, duration: 0.6),
        SCNAction.moveBy(x: 0, y: CGFloat(-0.15), z: 0, duration: 0.6)])))
    return n
}

func buildKey() -> SCNNode {
    let n = SCNNode()
    let shaft = SCNNode(geometry: SCNBox(width: 0.08, height: 0.08, length: 0.6, chamferRadius: 0.02))
    shaft.geometry!.materials = [mm(cGold, e: cGold, con: true)]
    shaft.position = SCNVector3(CGFloat(0), CGFloat(0.5), CGFloat(0))
    shaft.eulerAngles.x = CGFloat.pi / CGFloat(2)
    n.addChildNode(shaft)
    let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.15, pipeRadius: 0.04))
    ring.geometry!.materials = [mm(cGold, e: cGold, con: true)]
    ring.position = SCNVector3(CGFloat(0), CGFloat(0.85), CGFloat(0))
    n.addChildNode(ring)
    n.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi*2, z: 0, duration: 2.5)))
    n.runAction(SCNAction.repeatForever(SCNAction.sequence([
        SCNAction.moveBy(x: 0, y: CGFloat(0.2), z: 0, duration: 0.7),
        SCNAction.moveBy(x: 0, y: CGFloat(-0.2), z: 0, duration: 0.7)])))
    return n
}

func buildStairs() -> SCNNode {
    let n = SCNNode()
    for i in 0..<4 {
        let step = SCNNode(geometry: SCNBox(width: 1.5, height: 0.25, length: 0.5, chamferRadius: 0.02))
        step.geometry!.materials = [mm(NSColor(red: 0.35, green: 0.3, blue: 0.25, alpha: 1))]
        step.position = SCNVector3(CGFloat(0), CGFloat(i) * CGFloat(0.25), CGFloat(i) * CGFloat(0.4) - CGFloat(0.6))
        n.addChildNode(step)
    }
    let glow = SCNNode(geometry: SCNSphere(radius: 0.3))
    glow.geometry!.materials = [mm(cGold, e: cGold, con: true)]
    glow.position = SCNVector3(CGFloat(0), CGFloat(0.3), CGFloat(-1.0))
    glow.runAction(SCNAction.repeatForever(SCNAction.sequence([
        SCNAction.fadeOpacity(to: 0.4, duration: 0.8),
        SCNAction.fadeOpacity(to: 1.0, duration: 0.8)])))
    n.addChildNode(glow)
    // Add point light
    let light = SCNNode(); light.light = SCNLight()
    light.light!.type = .omni; light.light!.color = NSColor(red: 1, green: 0.85, blue: 0.4, alpha: 1)
    light.light!.intensity = 300; light.light!.attenuationStartDistance = 2
    light.light!.attenuationEndDistance = 8
    light.position = SCNVector3(CGFloat(0), CGFloat(1.5), CGFloat(0)); n.addChildNode(light)
    return n
}

func buildTorch() -> SCNNode {
    let n = SCNNode()
    let stick = SCNNode(geometry: SCNCylinder(radius: 0.04, height: 0.6))
    stick.geometry!.materials = [mm(NSColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1))]
    stick.position = SCNVector3(CGFloat(0), CGFloat(1.8), CGFloat(0)); n.addChildNode(stick)
    let flame = SCNNode(geometry: SCNSphere(radius: 0.1))
    flame.geometry!.materials = [mm(cOrange, e: cOrange, con: true)]
    flame.position = SCNVector3(CGFloat(0), CGFloat(2.15), CGFloat(0)); n.addChildNode(flame)
    flame.runAction(SCNAction.repeatForever(SCNAction.sequence([
        SCNAction.scale(to: 1.3, duration: 0.2), SCNAction.scale(to: 0.8, duration: 0.3)])))
    let light = SCNNode(); light.light = SCNLight()
    light.light!.type = .omni
    light.light!.color = NSColor(red: 1, green: 0.7, blue: 0.3, alpha: 1)
    light.light!.intensity = 200
    light.light!.attenuationStartDistance = 2; light.light!.attenuationEndDistance = 10
    light.position = SCNVector3(CGFloat(0), CGFloat(2.2), CGFloat(0)); n.addChildNode(light)
    return n
}

// MARK: - Projectiles
func buildFireball() -> SCNNode {
    let n = SCNNode(geometry: SCNSphere(radius: 0.18))
    n.geometry!.materials = [mm(cPurple, e: cPurple, con: true)]
    let ps = SCNParticleSystem(); ps.birthRate = 60; ps.particleLifeSpan = 0.3
    ps.particleSize = 0.08; ps.particleColor = cPurple; ps.blendMode = .additive
    ps.emitterShape = SCNSphere(radius: 0.05); ps.particleVelocity = 2
    ps.spreadingAngle = 180; ps.isAffectedByGravity = false
    n.addParticleSystem(ps)
    return n
}

func buildDemonFireball() -> SCNNode {
    let n = SCNNode(geometry: SCNSphere(radius: 0.22))
    n.geometry!.materials = [mm(cOrange, e: cOrange, con: true)]
    let ps = SCNParticleSystem(); ps.birthRate = 80; ps.particleLifeSpan = 0.35
    ps.particleSize = 0.1; ps.particleColor = cOrange; ps.blendMode = .additive
    ps.emitterShape = SCNSphere(radius: 0.06); ps.particleVelocity = 3
    ps.spreadingAngle = 180; ps.isAffectedByGravity = false
    n.addParticleSystem(ps)
    return n
}

func makeHitPS(color: NSColor) -> SCNParticleSystem {
    let ps = SCNParticleSystem(); ps.birthRate = 200; ps.particleLifeSpan = 0.4
    ps.emissionDuration = 0.05; ps.loops = false; ps.particleSize = 0.1
    ps.particleColor = color; ps.blendMode = .additive
    ps.emitterShape = SCNSphere(radius: 0.2); ps.particleVelocity = 8
    ps.spreadingAngle = 180; ps.isAffectedByGravity = false
    return ps
}

// MARK: - First-person weapon node (visible at bottom-right of camera)
func buildFPWeapon(name: String) -> SCNNode {
    let root = SCNNode(); root.name = "fpWeapon"
    switch name {
    case "BROADSWORD":
        let blade = SCNNode(geometry: SCNBox(width: 0.07, height: 0.07, length: 1.2, chamferRadius: 0.02))
        blade.geometry!.materials = [mm(NSColor(white: 0.7, alpha: 1), e: NSColor(red: 0.1, green: 0.15, blue: 0.25, alpha: 1))]
        blade.position = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(-0.7))
        root.addChildNode(blade)
        let edge = SCNNode(geometry: SCNBox(width: 0.02, height: 0.09, length: 1.1, chamferRadius: 0.01))
        edge.geometry!.materials = [mm(cCyan, e: cCyan, con: true)]
        edge.position = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(-0.7))
        root.addChildNode(edge)
        let guard_ = SCNNode(geometry: SCNBox(width: 0.3, height: 0.06, length: 0.06, chamferRadius: 0.02))
        guard_.geometry!.materials = [mm(cGold)]
        guard_.position = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(-0.1))
        root.addChildNode(guard_)
        let hilt = SCNNode(geometry: SCNCylinder(radius: 0.03, height: 0.25))
        hilt.geometry!.materials = [mm(NSColor(red: 0.35, green: 0.2, blue: 0.1, alpha: 1))]
        hilt.position = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(0.08))
        hilt.eulerAngles.x = CGFloat.pi / CGFloat(2)
        root.addChildNode(hilt)
    case "TWIN DAGGERS":
        for s: CGFloat in [-1, 1] {
            let blade = SCNNode(geometry: SCNBox(width: 0.04, height: 0.04, length: 0.6, chamferRadius: 0.01))
            blade.geometry!.materials = [mm(NSColor(white: 0.75, alpha: 1), e: NSColor(red: 0.05, green: 0.2, blue: 0.1, alpha: 1))]
            blade.position = SCNVector3(s * CGFloat(0.12), CGFloat(0), CGFloat(-0.4))
            root.addChildNode(blade)
            let edge = SCNNode(geometry: SCNBox(width: 0.015, height: 0.05, length: 0.5, chamferRadius: 0.005))
            edge.geometry!.materials = [mm(cGreen, e: cGreen, con: true)]
            edge.position = SCNVector3(s * CGFloat(0.12), CGFloat(0), CGFloat(-0.4))
            root.addChildNode(edge)
        }
    case "WAR HAMMER":
        let shaft = SCNNode(geometry: SCNCylinder(radius: 0.04, height: 1.0))
        shaft.geometry!.materials = [mm(NSColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 1))]
        shaft.position = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(-0.4))
        shaft.eulerAngles.x = CGFloat.pi / CGFloat(2)
        root.addChildNode(shaft)
        let head = SCNNode(geometry: SCNBox(width: 0.25, height: 0.2, length: 0.2, chamferRadius: 0.03))
        head.geometry!.materials = [mm(NSColor(white: 0.4, alpha: 1), e: NSColor(red: 0.2, green: 0.1, blue: 0.0, alpha: 1))]
        head.position = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(-0.95))
        root.addChildNode(head)
    default: // Default sword
        let blade = SCNNode(geometry: SCNBox(width: 0.06, height: 0.06, length: 1.0, chamferRadius: 0.02))
        blade.geometry!.materials = [mm(NSColor(white: 0.7, alpha: 1), e: NSColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1))]
        blade.position = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(-0.6))
        root.addChildNode(blade)
        let edge = SCNNode(geometry: SCNBox(width: 0.02, height: 0.08, length: 0.9, chamferRadius: 0.01))
        edge.geometry!.materials = [mm(cCyan, e: cCyan, con: true)]
        edge.position = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(-0.6))
        root.addChildNode(edge)
        let guard_ = SCNNode(geometry: SCNBox(width: 0.25, height: 0.05, length: 0.05, chamferRadius: 0.02))
        guard_.geometry!.materials = [mm(cGold)]
        guard_.position = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(-0.08))
        root.addChildNode(guard_)
        let hilt = SCNNode(geometry: SCNCylinder(radius: 0.025, height: 0.2))
        hilt.geometry!.materials = [mm(NSColor(red: 0.35, green: 0.2, blue: 0.1, alpha: 1))]
        hilt.position = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(0.06))
        hilt.eulerAngles.x = CGFloat.pi / CGFloat(2)
        root.addChildNode(hilt)
    }
    return root
}

// MARK: - Data Types
struct EnemyData {
    let node: SCNNode; var type: Int; var hp: Int; var maxHp: Int
    var radius: CGFloat; var speed: CGFloat; var damage: Int
    var atkRange: CGFloat; var atkCD: CGFloat; var shootCD: CGFloat
    var knockVel: SCNVector3; var state: Int // 0=idle 1=chase 2=attack 3=hurt
    var hurtT: CGFloat; var seenPlayer: Bool
}
struct ProjData { let node: SCNNode; var vel: SCNVector3; var life: CGFloat; var damage: Int }
struct ItemData { let node: SCNNode; var type: Int; var gx: Int; var gy: Int }

// MARK: - GameView (first-person: captures mouse delta)
class GameView: SCNView {
    var heldKeys: Set<UInt16> = []
    var pressedKeys: Set<UInt16> = []
    var mouseDX: CGFloat = 0
    var mouseDY: CGFloat = 0
    var mouseClicked = false
    var mouseCaptured = false

    override var acceptsFirstResponder: Bool { true }
    override func performKeyEquivalent(with event: NSEvent) -> Bool { false }

    override func keyDown(with event: NSEvent) {
        heldKeys.insert(event.keyCode)
        if !event.isARepeat { pressedKeys.insert(event.keyCode) }
    }
    override func keyUp(with event: NSEvent) { heldKeys.remove(event.keyCode) }

    override func mouseDown(with event: NSEvent) {
        mouseClicked = true
        if !mouseCaptured { captureMouse() }
    }

    override func mouseMoved(with event: NSEvent) {
        if mouseCaptured {
            mouseDX += event.deltaX
            mouseDY += event.deltaY
        }
    }
    override func mouseDragged(with event: NSEvent) {
        if mouseCaptured {
            mouseDX += event.deltaX
            mouseDY += event.deltaY
        }
    }

    func captureMouse() {
        mouseCaptured = true
        CGAssociateMouseAndMouseCursorPosition(0)
        NSCursor.hide()
    }
    func releaseMouse() {
        mouseCaptured = false
        CGAssociateMouseAndMouseCursorPosition(1)
        NSCursor.unhide()
    }

    func consumePressed() -> Set<UInt16> {
        let p = pressedKeys; pressedKeys.removeAll(); return p
    }
    func consumeMouse() -> (CGFloat, CGFloat, Bool) {
        let dx = mouseDX; let dy = mouseDY; let clicked = mouseClicked
        mouseDX = 0; mouseDY = 0; mouseClicked = false
        return (dx, dy, clicked)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self, userInfo: nil)
        addTrackingArea(area)
    }
}

// MARK: - GameController
class GameController: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    var view: GameView!
    // First-person camera nodes
    var yawNode: SCNNode!      // sits at player position, rotates Y
    var cameraNode: SCNNode!   // child of yaw, rotates X (pitch)
    var weaponNode: SCNNode!   // child of camera, visible weapon
    var playerLight: SCNNode!
    var gameNode: SCNNode!
    var hudScene: SKScene!
    var dungeonNode: SCNNode!

    // HUD elements
    var hpBar: SKShapeNode!; var hpBG: SKShapeNode!
    var xpBar: SKShapeNode!; var xpBG: SKShapeNode!
    var floorLabel: SKLabelNode!; var levelLabel: SKLabelNode!
    var killLabel: SKLabelNode!; var msgLabel: SKLabelNode!
    var keyIcon: SKNode!; var weaponLabel: SKLabelNode!
    var crossH: SKNode!; var crossV: SKNode!
    var menuNode: SKNode?; var deathNode: SKNode?; var upgradeNode: SKNode?
    // Minimap
    var mapNode: SKNode!; var mapFloor: SKShapeNode!; var mapPlayer: SKShapeNode!
    var mapEnemyDots: [SKShapeNode] = []

    var grid: [[Int]] = []; var rooms: [Room] = []
    var explored: [[Bool]] = []
    var enemies: [EnemyData] = []
    var projectiles: [ProjData] = []
    var items: [ItemData] = []
    var stairsNode: SCNNode?; var stairsRoom = -1

    var state = "menu"
    var lastTime: TimeInterval = 0
    var floorNum = 1; var score = 0; var killCount = 0
    // Player stats
    var pHP = 100; var pMaxHP = 100; var pDmg = 22
    var pSpdMult: CGFloat = 1; var pAtkMult: CGFloat = 1
    var pRangeMult: CGFloat = 1; var pKBMult: CGFloat = 1
    var pLifesteal: CGFloat = 0; var pRegen: CGFloat = 0
    var pShield = 0
    var pXP = 0; var pLevel = 1
    var pAtkCD: CGFloat = 0; var pDashT: CGFloat = 0; var pDashCD: CGFloat = 0
    var pDashDir = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(-1))
    var pInv: CGFloat = 0; var hasKey = false
    var shakeAmt: CGFloat = 0; var hitPause: CGFloat = 0
    var weaponName = "SWORD"
    var headBobT: CGFloat = 0
    var regenAccum: CGFloat = 0
    // Yaw / pitch
    var yawAngle: CGFloat = 0
    var pitchAngle: CGFloat = 0

    func xpToLevel() -> Int { return pLevel * 80 + 40 }

    func setup(_ v: GameView) {
        view = v; view.scene = scene; view.delegate = self
        view.isPlaying = true; view.preferredFramesPerSecond = 60
        view.antialiasingMode = .multisampling4X; view.backgroundColor = .black
        scene.background.contents = NSColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
        // Fog
        scene.fogStartDistance = FOG_START; scene.fogEndDistance = FOG_END
        scene.fogDensityExponent = 2.0
        scene.fogColor = NSColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
        setupLighting(); setupCamera(); setupHUD(); showMenu()
    }

    func setupLighting() {
        let amb = SCNNode(); amb.light = SCNLight()
        amb.light!.type = .ambient; amb.light!.color = NSColor(white: 0.06, alpha: 1)
        scene.rootNode.addChildNode(amb)
        let dir = SCNNode(); dir.light = SCNLight()
        dir.light!.type = .directional; dir.light!.color = NSColor(white: 0.15, alpha: 1)
        dir.eulerAngles = SCNVector3(CGFloat(-0.8), CGFloat(0.3), CGFloat(0))
        scene.rootNode.addChildNode(dir)
    }

    func setupCamera() {
        yawNode = SCNNode()
        cameraNode = SCNNode(); cameraNode.camera = SCNCamera()
        cameraNode.camera!.zFar = 200; cameraNode.camera!.fieldOfView = 75
        cameraNode.camera!.zNear = 0.1
        cameraNode.camera!.wantsHDR = true
        cameraNode.camera!.bloomIntensity = 1.0; cameraNode.camera!.bloomThreshold = 0.3
        cameraNode.camera!.bloomBlurRadius = 10
        cameraNode.camera!.vignettingIntensity = 0.8; cameraNode.camera!.vignettingPower = 1.5
        cameraNode.position = SCNVector3(CGFloat(0), CAM_HEIGHT, CGFloat(0))
        yawNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(yawNode)
        // Weapon attached to camera
        weaponNode = buildFPWeapon(name: "SWORD")
        weaponNode.position = SCNVector3(CGFloat(0.35), CGFloat(-0.3), CGFloat(-0.5))
        weaponNode.eulerAngles = SCNVector3(CGFloat(0.1), CGFloat(-0.2), CGFloat(0))
        cameraNode.addChildNode(weaponNode)
        // Player omni light
        playerLight = SCNNode(); playerLight.light = SCNLight()
        playerLight.light!.type = .omni
        playerLight.light!.color = NSColor(red: 0.35, green: 0.35, blue: 0.5, alpha: 1)
        playerLight.light!.intensity = 500
        playerLight.light!.attenuationStartDistance = 3; playerLight.light!.attenuationEndDistance = 14
        playerLight.position = SCNVector3(CGFloat(0), CGFloat(0.5), CGFloat(0))
        cameraNode.addChildNode(playerLight)
    }

    func setupHUD() {
        hudScene = SKScene(size: CGSize(width: WIN_W, height: WIN_H))
        hudScene.backgroundColor = .clear

        // HP bar
        hpBG = SKShapeNode(rect: CGRect(x: 30, y: WIN_H-45, width: 220, height: 16), cornerRadius: 3)
        hpBG.fillColor = NSColor(white: 0.1, alpha: 0.8)
        hpBG.strokeColor = NSColor(white: 0.3, alpha: 0.5); hpBG.lineWidth = 1; hpBG.zPosition = 10
        hudScene.addChild(hpBG)
        hpBar = SKShapeNode(rect: CGRect(x: 30, y: WIN_H-45, width: 220, height: 16), cornerRadius: 3)
        hpBar.fillColor = cGreen; hpBar.strokeColor = .clear; hpBar.zPosition = 11
        hudScene.addChild(hpBar)
        let hpLbl = SKLabelNode(text: "HP"); hpLbl.fontName = "Menlo"; hpLbl.fontSize = 9
        hpLbl.fontColor = NSColor(white: 0.5, alpha: 1); hpLbl.horizontalAlignmentMode = .left
        hpLbl.position = CGPoint(x: 30, y: WIN_H-60); hpLbl.zPosition = 10; hudScene.addChild(hpLbl)

        // XP bar
        xpBG = SKShapeNode(rect: CGRect(x: 30, y: WIN_H-75, width: 220, height: 10), cornerRadius: 2)
        xpBG.fillColor = NSColor(white: 0.08, alpha: 0.8)
        xpBG.strokeColor = NSColor(white: 0.2, alpha: 0.5); xpBG.lineWidth = 1; xpBG.zPosition = 10
        hudScene.addChild(xpBG)
        xpBar = SKShapeNode(rect: CGRect(x: 30, y: WIN_H-75, width: 0, height: 10), cornerRadius: 2)
        xpBar.fillColor = cCyan; xpBar.strokeColor = .clear; xpBar.zPosition = 11
        hudScene.addChild(xpBar)
        let xpLbl = SKLabelNode(text: "XP"); xpLbl.fontName = "Menlo"; xpLbl.fontSize = 8
        xpLbl.fontColor = NSColor(white: 0.4, alpha: 1); xpLbl.horizontalAlignmentMode = .left
        xpLbl.position = CGPoint(x: 30, y: WIN_H-87); xpLbl.zPosition = 10; hudScene.addChild(xpLbl)

        // Level label
        levelLabel = SKLabelNode(text: "LV 1"); levelLabel.fontName = "Menlo-Bold"
        levelLabel.fontSize = 14; levelLabel.fontColor = cCyan
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.position = CGPoint(x: 255, y: WIN_H-45); levelLabel.zPosition = 10
        hudScene.addChild(levelLabel)

        // Floor label
        floorLabel = SKLabelNode(text: "FLOOR 1"); floorLabel.fontName = "Menlo-Bold"
        floorLabel.fontSize = 16; floorLabel.fontColor = cGold
        floorLabel.position = CGPoint(x: WIN_W/2, y: WIN_H-35); floorLabel.zPosition = 10
        hudScene.addChild(floorLabel)

        // Kill count (top right)
        killLabel = SKLabelNode(text: "KILLS: 0"); killLabel.fontName = "Menlo-Bold"
        killLabel.fontSize = 14; killLabel.fontColor = .white
        killLabel.horizontalAlignmentMode = .right
        killLabel.position = CGPoint(x: WIN_W-30, y: WIN_H-35); killLabel.zPosition = 10
        hudScene.addChild(killLabel)

        // Weapon name (bottom center)
        weaponLabel = SKLabelNode(text: "SWORD"); weaponLabel.fontName = "Menlo-Bold"
        weaponLabel.fontSize = 13; weaponLabel.fontColor = NSColor(white: 0.5, alpha: 1)
        weaponLabel.position = CGPoint(x: WIN_W/2, y: 20); weaponLabel.zPosition = 10
        hudScene.addChild(weaponLabel)

        // Crosshair
        crossH = SKShapeNode(rect: CGRect(x: -10, y: -1, width: 20, height: 2))
        (crossH as! SKShapeNode).fillColor = NSColor(white: 1, alpha: 0.6)
        (crossH as! SKShapeNode).strokeColor = .clear
        crossH.position = CGPoint(x: WIN_W/2, y: WIN_H/2); crossH.zPosition = 15
        hudScene.addChild(crossH)
        crossV = SKShapeNode(rect: CGRect(x: -1, y: -10, width: 2, height: 20))
        (crossV as! SKShapeNode).fillColor = NSColor(white: 1, alpha: 0.6)
        (crossV as! SKShapeNode).strokeColor = .clear
        crossV.position = CGPoint(x: WIN_W/2, y: WIN_H/2); crossV.zPosition = 15
        hudScene.addChild(crossV)

        // Key icon
        keyIcon = SKNode(); keyIcon.position = CGPoint(x: WIN_W/2, y: 55); keyIcon.zPosition = 10
        let kBg = SKShapeNode(rect: CGRect(x: -60, y: -12, width: 120, height: 24), cornerRadius: 5)
        kBg.fillColor = NSColor(red: 0.1, green: 0.08, blue: 0.02, alpha: 0.8)
        kBg.strokeColor = cGold; kBg.lineWidth = 1; keyIcon.addChild(kBg)
        let kLbl = SKLabelNode(text: "KEY FOUND"); kLbl.fontName = "Menlo-Bold"; kLbl.fontSize = 12
        kLbl.fontColor = cGold; kLbl.verticalAlignmentMode = .center; keyIcon.addChild(kLbl)
        keyIcon.isHidden = true; hudScene.addChild(keyIcon)

        // Message label
        msgLabel = SKLabelNode(text: ""); msgLabel.fontName = "Menlo-Bold"; msgLabel.fontSize = 18
        msgLabel.fontColor = .white; msgLabel.position = CGPoint(x: WIN_W/2, y: WIN_H/2 + 80)
        msgLabel.zPosition = 30; hudScene.addChild(msgLabel)

        // Minimap (bottom right)
        mapNode = SKNode(); mapNode.position = CGPoint(x: WIN_W - 125, y: 15); mapNode.zPosition = 10
        let mapBG = SKShapeNode(rect: CGRect(x: -5, y: -5, width: 110, height: 110), cornerRadius: 4)
        mapBG.fillColor = NSColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 0.75)
        mapBG.strokeColor = NSColor(white: 0.2, alpha: 0.5); mapBG.lineWidth = 1
        mapNode.addChild(mapBG)
        mapFloor = SKShapeNode(); mapFloor.fillColor = NSColor(white: 0.25, alpha: 0.7)
        mapFloor.strokeColor = .clear; mapNode.addChild(mapFloor)
        mapPlayer = SKShapeNode(circleOfRadius: 3)
        mapPlayer.fillColor = cCyan; mapPlayer.strokeColor = .clear; mapPlayer.zPosition = 5
        mapNode.addChild(mapPlayer)
        hudScene.addChild(mapNode)

        view.overlaySKScene = hudScene
    }

    // MARK: - Menu
    func showMenu() {
        state = "menu"; view.releaseMouse()
        deathNode?.removeFromParent(); deathNode = nil
        upgradeNode?.removeFromParent(); upgradeNode = nil
        gameNode?.removeFromParentNode(); gameNode = nil

        let mn = SKNode(); mn.zPosition = 50
        let t = SKLabelNode(text: "SHADOW KEEP"); t.fontName = "Menlo-Bold"; t.fontSize = 52
        t.fontColor = cCyan; t.position = CGPoint(x: WIN_W/2, y: WIN_H*0.62); mn.addChild(t)
        let sub = SKLabelNode(text: "FIRST DESCENT"); sub.fontName = "Menlo"; sub.fontSize = 16
        sub.fontColor = NSColor(white: 0.4, alpha: 1)
        sub.position = CGPoint(x: WIN_W/2, y: WIN_H*0.55); mn.addChild(sub)
        let s = SKLabelNode(text: "[ PRESS SPACE TO DESCEND ]"); s.fontName = "Menlo"; s.fontSize = 16
        s.fontColor = NSColor(white: 0.6, alpha: 1); s.position = CGPoint(x: WIN_W/2, y: WIN_H*0.36)
        s.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.8), SKAction.fadeAlpha(to: 0.9, duration: 0.8)])))
        mn.addChild(s)
        let c = SKLabelNode(text: "WASD: Move   Mouse: Look   Click: Attack   Space: Dash   E: Interact   ESC: Release Mouse")
        c.fontName = "Menlo"; c.fontSize = 10; c.fontColor = NSColor(white: 0.3, alpha: 1)
        c.position = CGPoint(x: WIN_W/2, y: WIN_H*0.27); mn.addChild(c)
        hudScene.addChild(mn); menuNode = mn
        setHUDVisible(false)
    }

    func setHUDVisible(_ v: Bool) {
        hpBar.isHidden = !v; hpBG.isHidden = !v; xpBar.isHidden = !v; xpBG.isHidden = !v
        floorLabel.isHidden = !v; levelLabel.isHidden = !v; killLabel.isHidden = !v
        mapNode.isHidden = !v; weaponLabel.isHidden = !v
        crossH.isHidden = !v; crossV.isHidden = !v
    }

    // MARK: - Start Game
    func startGame() {
        menuNode?.removeFromParent(); menuNode = nil
        deathNode?.removeFromParent(); deathNode = nil
        floorNum = 1; score = 0; killCount = 0
        pHP = 100; pMaxHP = 100; pDmg = 22
        pSpdMult = 1; pAtkMult = 1; pRangeMult = 1; pKBMult = 1
        pLifesteal = 0; pRegen = 0; pShield = 0
        pXP = 0; pLevel = 1; weaponName = "SWORD"
        yawAngle = 0; pitchAngle = 0
        setHUDVisible(true); generateFloor()
        view.captureMouse()
    }

    func generateFloor() {
        upgradeNode?.removeFromParent(); upgradeNode = nil
        gameNode?.removeFromParentNode()
        gameNode = SCNNode(); scene.rootNode.addChildNode(gameNode)
        enemies = []; projectiles = []; items = []; hasKey = false; keyIcon.isHidden = true

        let result = generateDungeon(floor: floorNum)
        grid = result.0; rooms = result.1
        explored = Array(repeating: Array(repeating: false, count: GRID_W), count: GRID_H)

        dungeonNode = renderDungeon(grid: grid)
        gameNode.addChildNode(dungeonNode)

        // Player position (yawNode)
        let spawn = rooms[0]
        let spawnPos = SCNVector3(CGFloat(spawn.cx) * TILE, CGFloat(0), CGFloat(spawn.cy) * TILE)
        yawNode.position = spawnPos
        exploreAround(spawnPos)

        // Rebuild weapon
        weaponNode.removeFromParentNode()
        weaponNode = buildFPWeapon(name: weaponName)
        weaponNode.position = SCNVector3(CGFloat(0.35), CGFloat(-0.3), CGFloat(-0.5))
        weaponNode.eulerAngles = SCNVector3(CGFloat(0.1), CGFloat(-0.2), CGFloat(0))
        cameraNode.addChildNode(weaponNode)

        // Stairs in farthest room
        var maxDist: CGFloat = 0; stairsRoom = rooms.count - 1
        for i in 1..<rooms.count {
            let d = CGFloat(abs(rooms[i].cx - spawn.cx) + abs(rooms[i].cy - spawn.cy))
            if d > maxDist { maxDist = d; stairsRoom = i }
        }
        stairsNode = buildStairs()
        stairsNode!.position = SCNVector3(CGFloat(rooms[stairsRoom].cx) * TILE, CGFloat(0),
                                           CGFloat(rooms[stairsRoom].cy) * TILE)
        gameNode.addChildNode(stairsNode!)

        // Key in random room (not spawn, not stairs)
        var keyRoomIdx = 1
        if rooms.count > 2 {
            var candidates: [Int] = []
            for i in 1..<rooms.count { if i != stairsRoom { candidates.append(i) } }
            if candidates.isEmpty { candidates = [1] }
            keyRoomIdx = candidates[rI(0, candidates.count - 1)]
        }
        let kn = buildKey()
        kn.position = SCNVector3(CGFloat(rooms[keyRoomIdx].cx) * TILE, CGFloat(0), CGFloat(rooms[keyRoomIdx].cy) * TILE)
        gameNode.addChildNode(kn)
        items.append(ItemData(node: kn, type: 1, gx: rooms[keyRoomIdx].cx, gy: rooms[keyRoomIdx].cy))

        // Potions
        for _ in 0..<rI(1, 2) {
            let ri = rI(1, rooms.count - 1)
            let pn = buildPotion()
            let px = rI(rooms[ri].x + 1, rooms[ri].x + rooms[ri].w - 2)
            let py = rI(rooms[ri].y + 1, rooms[ri].y + rooms[ri].h - 2)
            pn.position = SCNVector3(CGFloat(px) * TILE, CGFloat(0), CGFloat(py) * TILE)
            gameNode.addChildNode(pn)
            items.append(ItemData(node: pn, type: 0, gx: px, gy: py))
        }

        // Torches
        for room in rooms {
            let torchCount = rI(1, 3)
            for _ in 0..<torchCount {
                let edge = rI(0, 3)
                var tx = 0; var ty = 0
                switch edge {
                case 0: tx = room.x; ty = rI(room.y, room.y + room.h - 1)
                case 1: tx = room.x + room.w - 1; ty = rI(room.y, room.y + room.h - 1)
                case 2: tx = rI(room.x, room.x + room.w - 1); ty = room.y
                default: tx = rI(room.x, room.x + room.w - 1); ty = room.y + room.h - 1
                }
                let tn = buildTorch()
                tn.position = SCNVector3(CGFloat(tx) * TILE, CGFloat(0), CGFloat(ty) * TILE)
                gameNode.addChildNode(tn)
            }
        }

        // Enemies
        let maxPerRoom = min(8, 2 + floorNum)
        for i in 1..<rooms.count {
            let count = rI(max(1, maxPerRoom - 1), maxPerRoom)
            for _ in 0..<count {
                let t = pickEnemyType(floor: floorNum)
                let en = buildEnemy(type: t)
                let ex = rI(rooms[i].x + 1, rooms[i].x + rooms[i].w - 2)
                let ey = rI(rooms[i].y + 1, rooms[i].y + rooms[i].h - 2)
                en.position = SCNVector3(CGFloat(ex) * TILE, CGFloat(0), CGFloat(ey) * TILE)
                gameNode.addChildNode(en)
                let stats = enemyStats(type: t, floor: floorNum)
                enemies.append(stats.0.withNode(en))
            }
        }

        pAtkCD = 0; pDashT = 0; pDashCD = 0; pInv = 0; lastTime = 0
        floorLabel.text = "FLOOR \(floorNum)"
        weaponLabel.text = weaponName
        state = "playing"
        showMessage("FLOOR \(floorNum)", dur: 1.5)
    }

    func pickEnemyType(floor: Int) -> Int {
        var pool: [Int] = [0, 1] // slime, skeleton always
        if floor >= 2 { pool.append(2) } // bat
        if floor >= 3 { pool.append(3) } // mage
        if floor >= 5 { pool.append(4) } // knight
        if floor >= 7 { pool.append(5) } // demon
        return pool[rI(0, pool.count - 1)]
    }

    struct EnemyTemplate {
        var type: Int; var hp: Int; var maxHp: Int; var radius: CGFloat; var speed: CGFloat
        var damage: Int; var atkRange: CGFloat; var shootCD: CGFloat
        func withNode(_ n: SCNNode) -> EnemyData {
            return EnemyData(node: n, type: type, hp: hp, maxHp: maxHp, radius: radius,
                speed: speed, damage: damage, atkRange: atkRange, atkCD: 0, shootCD: shootCD,
                knockVel: SCNVector3(CGFloat(0), CGFloat(0), CGFloat(0)), state: 0, hurtT: 0, seenPlayer: false)
        }
    }

    func enemyStats(type: Int, floor fl: Int) -> (EnemyTemplate, Void) {
        switch type {
        case 0: return (EnemyTemplate(type: 0, hp: 40+5*fl, maxHp: 40+5*fl, radius: 0.6,
                    speed: 3.5, damage: 8+2*fl, atkRange: 1.5, shootCD: 0), ())
        case 1: return (EnemyTemplate(type: 1, hp: 60+8*fl, maxHp: 60+8*fl, radius: 0.6,
                    speed: 5.0, damage: 12+2*fl, atkRange: 2.2, shootCD: 0), ())
        case 2: return (EnemyTemplate(type: 2, hp: 25+4*fl, maxHp: 25+4*fl, radius: 0.5,
                    speed: 6.0, damage: 10+2*fl, atkRange: 1.8, shootCD: 0), ())
        case 3: return (EnemyTemplate(type: 3, hp: 50+6*fl, maxHp: 50+6*fl, radius: 0.6,
                    speed: 2.5, damage: 18+3*fl, atkRange: 12.0, shootCD: 2.0), ())
        case 4: return (EnemyTemplate(type: 4, hp: 90+10*fl, maxHp: 90+10*fl, radius: 0.7,
                    speed: 5.5, damage: 15+3*fl, atkRange: 2.5, shootCD: 0), ())
        case 5: return (EnemyTemplate(type: 5, hp: 120+12*fl, maxHp: 120+12*fl, radius: 0.8,
                    speed: 4.0, damage: 20+4*fl, atkRange: 14.0, shootCD: 2.5), ())
        default: return (EnemyTemplate(type: 0, hp: 40, maxHp: 40, radius: 0.6,
                    speed: 3.5, damage: 8, atkRange: 1.5, shootCD: 0), ())
        }
    }

    func showMessage(_ text: String, dur: Double = 2.0) {
        msgLabel.text = text; msgLabel.alpha = 1
        msgLabel.removeAllActions()
        msgLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: dur), SKAction.fadeOut(withDuration: 0.5)]))
    }

    // MARK: - Exploration
    func exploreAround(_ pos: SCNVector3) {
        let gx = Int(round(pos.x / TILE)); let gy = Int(round(pos.z / TILE))
        let radius = 7
        for dy in -radius...radius {
            for dx in -radius...radius {
                let nx = gx + dx, ny = gy + dy
                if nx >= 0 && nx < GRID_W && ny >= 0 && ny < GRID_H { explored[ny][nx] = true }
            }
        }
    }

    // MARK: - Tile collision
    func canWalk(_ wx: CGFloat, _ wz: CGFloat) -> Bool {
        let gx = Int(round(wx / TILE)); let gy = Int(round(wz / TILE))
        guard gx >= 0 && gx < GRID_W && gy >= 0 && gy < GRID_H else { return false }
        return grid[gy][gx] == 1
    }

    // MARK: - Render Loop
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if lastTime == 0 { lastTime = time; return }
        let dt = CGFloat(time - lastTime); lastTime = time
        if dt > 0.1 { return }
        if hitPause > 0 { hitPause -= dt; return }
        let pressed = view.consumePressed()
        let (mdx, mdy, mclick) = view.consumeMouse()

        switch state {
        case "menu":
            if pressed.contains(49) { startGame() }
        case "playing":
            updatePlaying(dt, pressed: pressed, mdx: mdx, mdy: mdy, mclick: mclick)
        case "dead":
            if pressed.contains(49) { showMenu() }
        case "upgrading":
            if pressed.contains(18) { applyUpgrade(0) }      // key 1
            else if pressed.contains(19) { applyUpgrade(1) }  // key 2
            else if pressed.contains(20) { applyUpgrade(2) }  // key 3
        default: break
        }
    }

    // MARK: - Main Update
    func updatePlaying(_ dt: CGFloat, pressed: Set<UInt16>, mdx: CGFloat, mdy: CGFloat, mclick: Bool) {
        // ESC to toggle mouse capture
        if pressed.contains(53) {
            if view.mouseCaptured { view.releaseMouse() } else { view.captureMouse() }
        }

        // Mouse look
        if view.mouseCaptured {
            yawAngle -= mdx * MOUSE_SENS_X
            pitchAngle -= mdy * MOUSE_SENS_Y
            pitchAngle = max(-PITCH_LIMIT, min(PITCH_LIMIT, pitchAngle))
            yawNode.eulerAngles.y = yawAngle
            cameraNode.eulerAngles.x = pitchAngle
        }

        // WASD movement relative to camera facing
        let keys = view.heldKeys
        var moveX: CGFloat = 0, moveZ: CGFloat = 0
        if keys.contains(0)  { moveX -= 1 } // A
        if keys.contains(2)  { moveX += 1 } // D
        if keys.contains(13) { moveZ += 1 } // W (forward)
        if keys.contains(1)  { moveZ -= 1 } // S (backward)

        // Forward and right vectors from yaw
        let fwd = SCNVector3(-sin(yawAngle), CGFloat(0), -cos(yawAngle))
        let rgt = SCNVector3(cos(yawAngle), CGFloat(0), -sin(yawAngle))

        var moveDir = SCNVector3(
            fwd.x * moveZ + rgt.x * moveX,
            CGFloat(0),
            fwd.z * moveZ + rgt.z * moveX
        )
        let moveMag = moveDir.flat
        if moveMag > 0.001 { moveDir = moveDir.flatNorm }

        // Dash
        pDashCD -= dt
        if pressed.contains(49) && pDashCD <= 0 {
            if moveMag > 0.001 {
                pDashT = P_DASH_DUR; pDashCD = P_DASH_CD; pDashDir = moveDir
            } else {
                pDashT = P_DASH_DUR; pDashCD = P_DASH_CD; pDashDir = fwd
            }
        }

        let speed: CGFloat
        if pDashT > 0 {
            pDashT -= dt; speed = P_DASH_SPD
            moveDir = pDashDir
            pInv = 0.1
        } else {
            speed = moveMag > 0.001 ? P_SPEED * pSpdMult : 0
        }

        // Apply movement with collision
        if speed > 0.001 {
            let newX = yawNode.position.x + moveDir.x * speed * dt
            let newZ = yawNode.position.z + moveDir.z * speed * dt
            if canWalk(newX, yawNode.position.z) { yawNode.position.x = newX }
            if canWalk(yawNode.position.x, newZ) { yawNode.position.z = newZ }

            // Head bob
            if pDashT <= 0 {
                headBobT += dt * 10.0
                let bobAmount: CGFloat = 0.04
                cameraNode.position.y = CAM_HEIGHT + sin(headBobT) * bobAmount
            }
        }

        exploreAround(yawNode.position)

        // Attack
        pAtkCD -= dt
        if mclick && pAtkCD <= 0 && view.mouseCaptured { playerAttack() }

        // Invincibility
        if pInv > 0 { pInv -= dt }

        // Regen
        if pRegen > 0 {
            regenAccum += pRegen * dt
            if regenAccum >= 1 {
                let heal = Int(regenAccum)
                pHP = min(pMaxHP, pHP + heal)
                regenAccum -= CGFloat(heal)
            }
        }

        // Camera shake
        if shakeAmt > 0.01 {
            let sx = rF(-shakeAmt, shakeAmt)
            let sy = rF(-shakeAmt, shakeAmt)
            cameraNode.position.x = sx
            // keep y as head bob
            cameraNode.position.z = sy
            shakeAmt *= 0.85
        } else {
            shakeAmt = 0
            cameraNode.position.x = 0
            cameraNode.position.z = 0
        }

        updateEnemies(dt)
        updateProjectiles(dt)
        checkItems()
        checkStairs(pressed)
        updateHUD()
        updateMinimap()
    }

    // MARK: - Player Attack (first-person: ray from camera forward)
    func playerAttack() {
        pAtkCD = P_ATK_CD / pAtkMult

        // Weapon swing animation
        weaponNode.removeAllActions()
        let swingDur = Double(P_ATK_CD * 0.5 / pAtkMult)
        weaponNode.eulerAngles = SCNVector3(CGFloat(0.3), CGFloat(0.4), CGFloat(-0.1))
        weaponNode.runAction(SCNAction.sequence([
            SCNAction.rotateTo(x: CGFloat(-0.3), y: CGFloat(-0.5), z: CGFloat(0.1), duration: swingDur),
            SCNAction.rotateTo(x: CGFloat(0.1), y: CGFloat(-0.2), z: CGFloat(0), duration: 0.1)
        ]))

        // Attack direction = camera forward
        let atkDir = SCNVector3(-sin(yawAngle), CGFloat(0), -cos(yawAngle))
        let atkAngle = atan2(-atkDir.x, -atkDir.z)
        let range = P_ATK_RANGE * pRangeMult

        var hitAny = false
        for i in (0..<enemies.count).reversed() {
            let toE = enemies[i].node.position - yawNode.position
            let dist = toE.flat
            if dist > range { continue }
            let angleToE = atan2(-toE.x, -toE.z)
            var diff = atkAngle - angleToE
            while diff > CGFloat.pi { diff -= 2 * CGFloat.pi }
            while diff < -CGFloat.pi { diff += 2 * CGFloat.pi }
            if abs(diff) > P_ATK_ARC / 2 { continue }

            let dmg = pDmg + rI(-2, 3)
            enemies[i].hp -= dmg
            let kb = toE.flatNorm * KNOCKBACK * pKBMult
            enemies[i].knockVel = kb
            enemies[i].state = 3; enemies[i].hurtT = 0.2

            enemies[i].node.runAction(SCNAction.sequence([
                SCNAction.fadeOpacity(to: 0.2, duration: 0.04),
                SCNAction.fadeOpacity(to: 1.0, duration: 0.04)]))

            hitAny = true

            if pLifesteal > 0 { pHP = min(pMaxHP, pHP + Int(CGFloat(dmg) * pLifesteal)) }

            if enemies[i].hp <= 0 {
                let xpGain = enemies[i].type < XP_VALUES.count ? XP_VALUES[enemies[i].type] : 15
                pXP += xpGain; score += xpGain; killCount += 1

                let hitNode = SCNNode(); hitNode.position = enemies[i].node.position
                let eColor: NSColor
                switch enemies[i].type {
                case 0: eColor = cGreen; case 1: eColor = cOrange
                case 2: eColor = cPurple; case 3: eColor = cPurple
                case 4: eColor = cRed; case 5: eColor = cOrange
                default: eColor = .white
                }
                hitNode.addParticleSystem(makeHitPS(color: eColor))
                gameNode.addChildNode(hitNode)
                hitNode.runAction(SCNAction.sequence([
                    SCNAction.wait(duration: 1), SCNAction.removeFromParentNode()]))
                enemies[i].node.removeFromParentNode(); enemies.remove(at: i)
            } else {
                let hitNode = SCNNode(); hitNode.position = enemies[i].node.position
                hitNode.addParticleSystem(makeHitPS(color: .white))
                gameNode.addChildNode(hitNode)
                hitNode.runAction(SCNAction.sequence([
                    SCNAction.wait(duration: 0.8), SCNAction.removeFromParentNode()]))
            }
        }
        if hitAny { shakeAmt = 0.3; hitPause = 0.04 }

        // Check for level up
        checkLevelUp()
    }

    func checkLevelUp() {
        let needed = xpToLevel()
        if pXP >= needed {
            pXP -= needed
            pLevel += 1
            showUpgrades()
        }
    }

    // MARK: - Enemy AI
    func updateEnemies(_ dt: CGFloat) {
        let pp = yawNode.position
        for i in 0..<enemies.count {
            let pos = enemies[i].node.position
            let toP = pp - pos; let dist = toP.flat
            enemies[i].atkCD -= dt

            // Knockback
            if enemies[i].knockVel.flat > 0.5 {
                let kbMove = enemies[i].knockVel * dt
                let nx = pos.x + kbMove.x; let nz = pos.z + kbMove.z
                if canWalk(nx, nz) { enemies[i].node.position = SCNVector3(nx, pos.y, nz) }
                enemies[i].knockVel = enemies[i].knockVel * 0.85
            }

            // Hurt state
            if enemies[i].state == 3 {
                enemies[i].hurtT -= dt
                if enemies[i].hurtT <= 0 { enemies[i].state = 1 }
                continue
            }

            // Detection
            if dist < 14 { enemies[i].seenPlayer = true }
            if !enemies[i].seenPlayer { continue }

            enemies[i].node.look(at: SCNVector3(pp.x, CGFloat(0), pp.z))

            switch enemies[i].type {
            case 0: // Slime
                if dist > enemies[i].atkRange {
                    let dir = toP.flatNorm
                    let nx = pos.x + dir.x * enemies[i].speed * dt
                    let nz = pos.z + dir.z * enemies[i].speed * dt
                    if canWalk(nx, nz) { enemies[i].node.position = SCNVector3(nx, pos.y, nz) }
                } else if enemies[i].atkCD <= 0 {
                    if pInv <= 0 { playerTakeDamage(enemies[i].damage, from: pos) }
                    enemies[i].atkCD = 1.0
                }

            case 1: // Skeleton
                if dist > enemies[i].atkRange {
                    let dir = toP.flatNorm
                    let nx = pos.x + dir.x * enemies[i].speed * dt
                    let nz = pos.z + dir.z * enemies[i].speed * dt
                    if canWalk(nx, nz) { enemies[i].node.position = SCNVector3(nx, pos.y, nz) }
                } else if enemies[i].atkCD <= 0 {
                    if pInv <= 0 { playerTakeDamage(enemies[i].damage, from: pos) }
                    enemies[i].atkCD = 0.8
                }

            case 2: // Bat - fast swoop
                if dist > enemies[i].atkRange {
                    let dir = toP.flatNorm
                    let nx = pos.x + dir.x * enemies[i].speed * dt
                    let nz = pos.z + dir.z * enemies[i].speed * dt
                    if canWalk(nx, nz) { enemies[i].node.position = SCNVector3(nx, pos.y, nz) }
                } else if enemies[i].atkCD <= 0 {
                    if pInv <= 0 { playerTakeDamage(enemies[i].damage, from: pos) }
                    enemies[i].atkCD = 0.7
                }

            case 3: // Mage - keep distance, shoot fireballs
                if dist < 5 {
                    let away = (pos - pp).flatNorm
                    let nx = pos.x + away.x * enemies[i].speed * dt
                    let nz = pos.z + away.z * enemies[i].speed * dt
                    if canWalk(nx, nz) { enemies[i].node.position = SCNVector3(nx, pos.y, nz) }
                } else if dist > 14 {
                    let dir = toP.flatNorm
                    let nx = pos.x + dir.x * enemies[i].speed * dt
                    let nz = pos.z + dir.z * enemies[i].speed * dt
                    if canWalk(nx, nz) { enemies[i].node.position = SCNVector3(nx, pos.y, nz) }
                }
                enemies[i].shootCD -= dt
                if enemies[i].shootCD <= 0 && dist < 15 {
                    let fb = buildFireball()
                    fb.position = pos + SCNVector3(CGFloat(0), CGFloat(1.3), CGFloat(0))
                    let target = pp + SCNVector3(CGFloat(0), CAM_HEIGHT * CGFloat(0.5), CGFloat(0))
                    let dir = (target - fb.position).norm
                    projectiles.append(ProjData(node: fb, vel: dir * CGFloat(10), life: 4, damage: enemies[i].damage))
                    gameNode.addChildNode(fb)
                    enemies[i].shootCD = max(1.2, 2.5 - CGFloat(floorNum) * 0.1)
                }

            case 4: // Knight - fast melee
                if dist > enemies[i].atkRange {
                    let dir = toP.flatNorm
                    let nx = pos.x + dir.x * enemies[i].speed * dt
                    let nz = pos.z + dir.z * enemies[i].speed * dt
                    if canWalk(nx, nz) { enemies[i].node.position = SCNVector3(nx, pos.y, nz) }
                } else if enemies[i].atkCD <= 0 {
                    if pInv <= 0 { playerTakeDamage(enemies[i].damage, from: pos) }
                    enemies[i].atkCD = 0.6
                }

            case 5: // Demon - ranged spread projectiles
                if dist < 6 {
                    let away = (pos - pp).flatNorm
                    let nx = pos.x + away.x * enemies[i].speed * dt
                    let nz = pos.z + away.z * enemies[i].speed * dt
                    if canWalk(nx, nz) { enemies[i].node.position = SCNVector3(nx, pos.y, nz) }
                } else if dist > 16 {
                    let dir = toP.flatNorm
                    let nx = pos.x + dir.x * enemies[i].speed * dt
                    let nz = pos.z + dir.z * enemies[i].speed * dt
                    if canWalk(nx, nz) { enemies[i].node.position = SCNVector3(nx, pos.y, nz) }
                }
                enemies[i].shootCD -= dt
                if enemies[i].shootCD <= 0 && dist < 16 {
                    // Fire 3 spread projectiles
                    let baseDir = toP.flatNorm
                    let baseAngle = atan2(baseDir.x, baseDir.z)
                    for spread: CGFloat in [-0.3, 0, 0.3] {
                        let a = baseAngle + spread
                        let dir = SCNVector3(sin(a), CGFloat(0), cos(a))
                        let fb = buildDemonFireball()
                        fb.position = pos + SCNVector3(CGFloat(0), CGFloat(1.5), CGFloat(0))
                        projectiles.append(ProjData(node: fb, vel: dir * CGFloat(9), life: 3.5, damage: enemies[i].damage))
                        gameNode.addChildNode(fb)
                    }
                    enemies[i].shootCD = max(1.5, 3.0 - CGFloat(floorNum) * 0.1)
                }

            default: break
            }
            enemies[i].state = 1
        }
    }

    func updateProjectiles(_ dt: CGFloat) {
        for i in (0..<projectiles.count).reversed() {
            projectiles[i].life -= dt
            projectiles[i].node.position = projectiles[i].node.position + projectiles[i].vel * dt
            let dist = (projectiles[i].node.position - yawNode.position).flat
            if dist < 1.0 && pInv <= 0 {
                playerTakeDamage(projectiles[i].damage, from: projectiles[i].node.position)
                projectiles[i].node.removeFromParentNode(); projectiles.remove(at: i); continue
            }
            if !canWalk(projectiles[i].node.position.x, projectiles[i].node.position.z) {
                projectiles[i].node.removeFromParentNode(); projectiles.remove(at: i); continue
            }
            if projectiles[i].life <= 0 {
                projectiles[i].node.removeFromParentNode(); projectiles.remove(at: i)
            }
        }
    }

    func playerTakeDamage(_ amount: Int, from pos: SCNVector3) {
        if pInv > 0 { return }
        var dmg = amount
        if pShield > 0 {
            let absorbed = min(pShield, dmg)
            pShield -= absorbed; dmg -= absorbed
        }
        pHP -= dmg; pInv = 0.6; shakeAmt = 0.8
        if pHP <= 0 { pHP = 0; gameOver() }
    }

    func gameOver() {
        state = "dead"; view.releaseMouse()
        let dn = SKNode(); dn.zPosition = 50
        let bg = SKShapeNode(rect: CGRect(x: 0, y: 0, width: WIN_W, height: WIN_H))
        bg.fillColor = NSColor(red: 0.1, green: 0.0, blue: 0.0, alpha: 0.7); bg.strokeColor = .clear
        dn.addChild(bg)
        let t = SKLabelNode(text: "YOU DIED"); t.fontName = "Menlo-Bold"; t.fontSize = 48; t.fontColor = cRed
        t.position = CGPoint(x: WIN_W/2, y: WIN_H*0.6); dn.addChild(t)
        let sc = SKLabelNode(text: "Floor: \(floorNum)  |  Level: \(pLevel)  |  Kills: \(killCount)")
        sc.fontName = "Menlo"; sc.fontSize = 16; sc.fontColor = NSColor(white: 0.6, alpha: 1)
        sc.position = CGPoint(x: WIN_W/2, y: WIN_H*0.48); dn.addChild(sc)
        let r = SKLabelNode(text: "[ PRESS SPACE ]"); r.fontName = "Menlo"; r.fontSize = 16
        r.fontColor = NSColor(white: 0.5, alpha: 1); r.position = CGPoint(x: WIN_W/2, y: WIN_H*0.35)
        r.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.7), SKAction.fadeAlpha(to: 0.9, duration: 0.7)])))
        dn.addChild(r)
        dn.alpha = 0; dn.run(SKAction.fadeIn(withDuration: 0.5))
        hudScene.addChild(dn); deathNode = dn
    }

    // MARK: - Items
    func checkItems() {
        let pp = yawNode.position
        for i in (0..<items.count).reversed() {
            let dist = (items[i].node.position - pp).flat
            if dist < 1.8 {
                switch items[i].type {
                case 0: // Potion
                    let heal = min(pMaxHP - pHP, 30 + floorNum * 5)
                    pHP += heal
                    showMessage("+\(heal) HP", dur: 1.0)
                case 1: // Key
                    hasKey = true; keyIcon.isHidden = false
                    showMessage("KEY ACQUIRED", dur: 1.5)
                default: break
                }
                items[i].node.removeFromParentNode(); items.remove(at: i)
            }
        }
    }

    func checkStairs(_ pressed: Set<UInt16>) {
        guard let sn = stairsNode else { return }
        let dist = (sn.position - yawNode.position).flat
        if dist < 2.5 {
            if !hasKey {
                if msgLabel.alpha < 0.1 { showMessage("FIND THE KEY", dur: 1.0) }
            } else if pressed.contains(14) { // E key
                floorNum += 1
                // Check for pending level up
                checkLevelUp()
                if state != "upgrading" {
                    generateFloor()
                }
            }
        }
    }

    // MARK: - Upgrades (Card System)
    var upgradeCards: [Card] = []
    func showUpgrades() {
        state = "upgrading"; view.releaseMouse()
        let shuffled = ALL_CARDS.shuffled()
        upgradeCards = Array(shuffled.prefix(3))

        let un = SKNode(); un.zPosition = 50
        let bg = SKShapeNode(rect: CGRect(x: 0, y: 0, width: WIN_W, height: WIN_H))
        bg.fillColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.75); bg.strokeColor = .clear
        un.addChild(bg)
        let title = SKLabelNode(text: "LEVEL UP! CHOOSE A CARD"); title.fontName = "Menlo-Bold"
        title.fontSize = 22; title.fontColor = cGold
        title.position = CGPoint(x: WIN_W/2, y: WIN_H * 0.78); un.addChild(title)
        let lvlTxt = SKLabelNode(text: "Level \(pLevel)"); lvlTxt.fontName = "Menlo"
        lvlTxt.fontSize = 14; lvlTxt.fontColor = cCyan
        lvlTxt.position = CGPoint(x: WIN_W/2, y: WIN_H * 0.72); un.addChild(lvlTxt)

        for i in 0..<3 {
            let card = upgradeCards[i]
            let cx = WIN_W * CGFloat(i + 1) / CGFloat(4)
            let cardBG = SKShapeNode(rect: CGRect(x: cx - 110, y: WIN_H*0.3, width: 220, height: 220), cornerRadius: 10)
            cardBG.fillColor = NSColor(red: 0.06, green: 0.06, blue: 0.1, alpha: 0.95)
            let borderColor: NSColor
            switch card.category {
            case .weapon: borderColor = cGold
            case .upgrade: borderColor = cCyan
            case .buff: borderColor = cGreen
            }
            cardBG.strokeColor = borderColor; cardBG.lineWidth = 2; un.addChild(cardBG)

            let catLabel: String
            switch card.category {
            case .weapon: catLabel = "WEAPON"
            case .upgrade: catLabel = "UPGRADE"
            case .buff: catLabel = "BUFF"
            }
            let cat = SKLabelNode(text: catLabel); cat.fontName = "Menlo"; cat.fontSize = 10
            cat.fontColor = borderColor
            cat.position = CGPoint(x: cx, y: WIN_H*0.3 + 190); un.addChild(cat)

            let num = SKLabelNode(text: "[\(i+1)]"); num.fontName = "Menlo-Bold"; num.fontSize = 14
            num.fontColor = .white
            num.position = CGPoint(x: cx, y: WIN_H*0.3 + 165); un.addChild(num)
            let name = SKLabelNode(text: card.name); name.fontName = "Menlo-Bold"
            name.fontSize = 15; name.fontColor = .white
            name.position = CGPoint(x: cx, y: WIN_H*0.3 + 130); un.addChild(name)
            let desc = SKLabelNode(text: card.desc); desc.fontName = "Menlo"
            desc.fontSize = 11; desc.fontColor = NSColor(white: 0.55, alpha: 1)
            desc.position = CGPoint(x: cx, y: WIN_H*0.3 + 100); un.addChild(desc)
        }
        hudScene.addChild(un); upgradeNode = un
    }

    func applyUpgrade(_ index: Int) {
        guard index < upgradeCards.count else { return }
        let card = upgradeCards[index]
        switch card.id {
        case 1: // Broadsword
            pDmg = Int(CGFloat(pDmg) * 1.35); pAtkMult *= 0.85; weaponName = "BROADSWORD"
            rebuildWeapon()
        case 2: // Twin Daggers
            pAtkMult *= 1.4; pDmg = Int(CGFloat(pDmg) * 0.85); weaponName = "TWIN DAGGERS"
            rebuildWeapon()
        case 3: // War Hammer
            pDmg = Int(CGFloat(pDmg) * 1.5); pKBMult *= 2.0; pAtkMult *= 0.75; weaponName = "WAR HAMMER"
            rebuildWeapon()
        case 4: // Iron Hide
            pMaxHP += 30; pHP = min(pMaxHP, pHP + 30)
        case 5: // Keen Edge
            pDmg = Int(CGFloat(pDmg) * 1.2)
        case 6: // Quick Hands
            pAtkMult *= 1.25
        case 7: // Fleet Foot
            pSpdMult *= 1.2
        case 8: // Long Arms
            pRangeMult *= 1.25
        case 9: // Vampiric
            pLifesteal += 0.08
        case 10: // Second Wind
            pHP = pMaxHP
        case 11: // Shield Orb
            pShield += 40
        case 12: // Regeneration
            pRegen += 2.0
        default: break
        }
        upgradeNode?.removeFromParent(); upgradeNode = nil
        state = "playing"
        view.captureMouse()
        // If we were going to next floor, do it now
        if hasKey { generateFloor() }
        showMessage(card.name + " ACQUIRED!", dur: 1.2)
    }

    func rebuildWeapon() {
        weaponNode.removeFromParentNode()
        weaponNode = buildFPWeapon(name: weaponName)
        weaponNode.position = SCNVector3(CGFloat(0.35), CGFloat(-0.3), CGFloat(-0.5))
        weaponNode.eulerAngles = SCNVector3(CGFloat(0.1), CGFloat(-0.2), CGFloat(0))
        cameraNode.addChildNode(weaponNode)
        weaponLabel.text = weaponName
    }

    // MARK: - HUD Update
    func updateHUD() {
        let pct = CGFloat(pHP) / CGFloat(pMaxHP)
        hpBar.path = CGPath(roundedRect: CGRect(x: 30, y: WIN_H-45, width: 220*pct, height: 16),
                            cornerWidth: 3, cornerHeight: 3, transform: nil)
        if pShield > 0 {
            hpBar.fillColor = cGold
        } else {
            hpBar.fillColor = pct > 0.5 ? cGreen : (pct > 0.25 ? cGold : cRed)
        }

        let xpPct = CGFloat(pXP) / CGFloat(max(1, xpToLevel()))
        xpBar.path = CGPath(roundedRect: CGRect(x: 30, y: WIN_H-75, width: 220*min(xpPct, 1.0), height: 10),
                            cornerWidth: 2, cornerHeight: 2, transform: nil)

        levelLabel.text = "LV \(pLevel)"
        killLabel.text = "KILLS: \(killCount)"
    }

    func updateMinimap() {
        let path = CGMutablePath()
        let s: CGFloat = 2.3
        for y in 0..<GRID_H {
            for x in 0..<GRID_W {
                if explored[y][x] && grid[y][x] == 1 {
                    path.addRect(CGRect(x: CGFloat(x)*s, y: CGFloat(GRID_H-1-y)*s, width: s-0.3, height: s-0.3))
                }
            }
        }
        mapFloor.path = path

        let gx = Int(round(yawNode.position.x / TILE))
        let gy = Int(round(yawNode.position.z / TILE))
        mapPlayer.position = CGPoint(x: CGFloat(gx)*s + s/2, y: CGFloat(GRID_H-1-gy)*s + s/2)

        for d in mapEnemyDots { d.removeFromParent() }
        mapEnemyDots.removeAll()
        for e in enemies {
            let ex = Int(round(e.node.position.x / TILE))
            let ey = Int(round(e.node.position.z / TILE))
            if ex >= 0 && ex < GRID_W && ey >= 0 && ey < GRID_H && explored[ey][ex] {
                let dot = SKShapeNode(circleOfRadius: 1.5)
                let dotColor: NSColor
                switch e.type {
                case 0: dotColor = cGreen; case 1: dotColor = cOrange
                case 2: dotColor = cPurple; case 3: dotColor = cPurple
                case 4: dotColor = cRed; case 5: dotColor = cOrange
                default: dotColor = .white
                }
                dot.fillColor = dotColor
                dot.strokeColor = .clear; dot.zPosition = 3
                dot.position = CGPoint(x: CGFloat(ex)*s + s/2, y: CGFloat(GRID_H-1-ey)*s + s/2)
                mapNode.addChild(dot); mapEnemyDots.append(dot)
            }
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let controller = GameController()
    func applicationDidFinishLaunching(_ notification: Notification) {
        let scr = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        window = NSWindow(contentRect: NSRect(x: (scr.width-WIN_W)/2, y: (scr.height-WIN_H)/2,
                                              width: WIN_W, height: WIN_H),
                          styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.title = "SHADOW KEEP // FIRST DESCENT"
        window.backgroundColor = .black
        let gv = GameView(frame: NSRect(x: 0, y: 0, width: WIN_W, height: WIN_H))
        window.contentView = gv
        window.makeKeyAndOrderFront(nil); window.makeFirstResponder(gv)
        controller.setup(gv)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
