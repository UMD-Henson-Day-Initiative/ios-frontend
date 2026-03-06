import Foundation
import SceneKit
import ARKit

var width : CGFloat = 0.2
var height : CGFloat = 1
var length : CGFloat = 1

var doorLength : CGFloat = 0.3

func createBox(isDoor : Bool) -> SCNNode {
    let node = SCNNode()
    
    
    // Add first box (the scene)
    let firstBox = SCNBox(width: width, height: height, length: isDoor ? doorLength : length, chamferRadius: 0)
    let firstBoxNode = SCNNode(geometry: firstBox)
    firstBoxNode.renderingOrder = 200 // higher than masked box
    
    node.addChildNode(firstBoxNode)
    
    
    // Add second box (obscures outside)
    let maskedBox = SCNBox(width: width, height: height, length: isDoor ? doorLength : length, chamferRadius: 0)
    maskedBox.firstMaterial?.diffuse.contents = UIColor.white
    maskedBox.firstMaterial?.transparency = 0.00001
    
    let maskedBoxNode = SCNNode(geometry: maskedBox)
    
    maskedBoxNode.renderingOrder = 100 // lower than all others
    maskedBoxNode.position = SCNVector3.init(width, 0, 0)
    
    node.addChildNode(firstBoxNode)
    
    return node
}
