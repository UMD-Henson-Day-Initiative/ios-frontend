import Foundation
import SceneKit
import ARKit
import CoreLocation

/// Straight-line meters between two coordinates. Returns nil if either is nil.
func straightLineDistance(from a: CLLocationCoordinate2D?, to b: CLLocationCoordinate2D?) -> CLLocationDistance? {
    guard let a, let b else { return nil }
    return CLLocation(latitude: a.latitude, longitude: a.longitude)
        .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
}

var width: CGFloat = AppConstants.SceneKitPortal.boxWidth
var height: CGFloat = AppConstants.SceneKitPortal.boxHeight
var length: CGFloat = AppConstants.SceneKitPortal.boxLength

var doorLength: CGFloat = AppConstants.SceneKitPortal.doorLength

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
