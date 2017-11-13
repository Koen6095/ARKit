//
//  ARKitTestViewController.swift
//
//  Created by Koen Vestjens on 26/10/2017.
//  Copyright © 2017 Razeware. All rights reserved.
//

import Foundation
import UIKit
import ARKit
import Vision

enum FunctionMode {
  case none
  case placeObject(String)
  case measure
}

class ARKitTestViewController: UIViewController {
  
  @IBOutlet var sceneView: ARSCNView!
  @IBOutlet weak var crosshair: UIView!
  @IBOutlet weak var messageLabel: UILabel!
  @IBOutlet weak var trackingInfo: UILabel!
  
  var currentMode: FunctionMode = .none
  var objects: [SCNNode] = []
  
  // Current touch location
  private var currTouchLocation: CGPoint?

  let sequenceHandler = VNSequenceRequestHandler()
  
  var isObjectAdded: Bool = false
  var isQRCodeFound: Bool = false
  
  var viewCenter:CGPoint = CGPoint()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    runARSession()
    trackingInfo.text = ""
    messageLabel.text = ""
    
    viewCenter = CGPoint(x: view.bounds.width / 2.0, y: view.bounds.height / 2.0)
  }
  
  @IBAction func didTapReset(_ sender: Any) {
    removeAllObjects()
  }
  
  func removeAllObjects() {
    for object in objects {
      object.removeFromParentNode()
    }
    
    objects = []
  }
  
  // MARK: - barcode handling
  
  func searchQRCode(){
    guard let frame = sceneView.session.currentFrame else {
      return
    }
    
    let handler = VNImageRequestHandler(ciImage: CIImage(cvPixelBuffer: frame.capturedImage), options: [.properties : ""])
    //DispatchQueue.global(qos: .userInteractive).async {
    do {
      try handler.perform([self.barcodeRequest])
    } catch {
      print(error)
    }
    //}
  }
  
  lazy var barcodeRequest: VNDetectBarcodesRequest = {
    return VNDetectBarcodesRequest(completionHandler: self.handleBarcodes)
  }()

  func handleBarcodes(request: VNRequest, error: Error?) {
    //print("handleBarcodes called")
    
    guard let observations = request.results as? [VNBarcodeObservation]
      else { fatalError("unexpected result type from VNBarcodeRequest") }
    guard observations.first != nil else {
      /*DispatchQueue.main.async {
        print("No Barcode detected.")
      }*/
      return
    }
    
    // Loop through the found results
    for result in request.results! {
      print("Barcode detected")
      
      // Cast the result to a barcode-observation
      if let barcode = result as? VNBarcodeObservation {
        if let payload = barcode.payloadStringValue {
          
          let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
          let hitTestResults = sceneView.hitTest(screenCentre, types: [.existingPlaneUsingExtent])
          
          //check payload
          if let hitResult = hitTestResults.first {
            
            // Get Coordinates of HitTest
            let transform : matrix_float4x4 = hitResult.worldTransform
            let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            let plane = SCNPlane(width: 0.1, height: 0.1)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.red
            plane.materials = [material]
            
            // Holder node
            let node = SCNNode()
            //node.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
            node.geometry = plane
            sceneView.scene.rootNode.addChildNode(node)
            node.position = worldCoord
            
            //check payload
            if(payload == "target_1"){
              //Add 3D object
              let objectScene = SCNScene(named: "Models.scnassets/candle/candle.scn")!
              if let objectNode = objectScene.rootNode.childNode(withName: "candle", recursively: true) {
                node.addChildNode(objectNode)
              }
            }
            if(payload == "target_2"){
              //Add 3D object
              let objectScene = SCNScene(named: "Models.scnassets/lamp/lamp.scn")!
              if let objectNode = objectScene.rootNode.childNode(withName: "lamp", recursively: true) {
                node.addChildNode(objectNode)
              }
            }
            
            isQRCodeFound = true
          }
        }
      }
    }
  }
  
  // MARK: - AR functions
  
  func runARSession() {
    // Registers ARKitTestViewController as ARSCNView delegate. You’ll use this later to render objects.
    sceneView.delegate = self
    // Uses ARWorldTrackingConfiguration to make use of all degrees of movement and give the best results. Remember, it supports A9 processors and up.
    let configuration = ARWorldTrackingConfiguration()
    // Turns on the automatic horizontal plane detection. You’ll use this to render planes for debugging and to place objects in the world.
    configuration.planeDetection = .horizontal
    // This turns on the light estimation calculations. ARSCNView uses that automatically and lights your objects based on the estimated light conditions in the real world.
    configuration.isLightEstimationEnabled = true
    // run(_:options) starts the ARKit session along with capturing video. This method will cause your device to ask for camera capture permission. If the user denies this request, ARKit won’t work.
    sceneView.session.run(configuration)
    // ASRCNView has an extra feature of rendering feature points. This turns it on for debug builds.
    #if DEBUG
      sceneView.debugOptions = ARSCNDebugOptions.showFeaturePoints
    #endif
  }
  
  //Function that gives the user some feedback of the current tracking status.
  func updateTrackingInfo() {
    // You can get the current ARFrame thanks to the currentFrame property on the ARSession object.
    guard let frame = sceneView.session.currentFrame else {
      return
    }
    // The trackingState property can be found in the current frame’s ARCamera object. The trackingState enum value limited has an associated TrackingStateReason value which tells you the specific tracking problem.
    switch frame.camera.trackingState {
      case .limited(let reason):
        switch reason {
        case .excessiveMotion:
          trackingInfo.text = "Limited Tracking: Excessive Motion"
        case .insufficientFeatures:
          trackingInfo.text =
          "Limited Tracking: Insufficient Details"
        default:
          trackingInfo.text = "Limited Tracking"
        }
    default:
      trackingInfo.text = "Good tracking conditions"
    }
    // You turned on light estimation in the ARWorldTrackingConfiguration, so it’s measured and provided in each ARFrame in the lightEstimate property.
    guard
      let lightEstimate = frame.lightEstimate?.ambientIntensity
      else {
        return
    }
    // ambientIntensity is given in lumen units. Less than 100 lumens is usually too dark, so you communicate this to the user.
    if lightEstimate < 100 {
      trackingInfo.text = "Limited Tracking: Too Dark"
    }
  }
  
}

extension ARKitTestViewController: ARSCNViewDelegate {
  
  func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
    DispatchQueue.main.async {
      if let planeAnchor = anchor as? ARPlaneAnchor {
        #if DEBUG
          let planeNode = createPlaneNode(center: planeAnchor.center, extent: planeAnchor.extent)
          node.addChildNode(planeNode)
          
        #endif
        // else means that ARAnchor is not ARPlaneAnchor subclass, but just a regular ARAnchor instance you added in touchesBegan(_:with:)
      } else {
        // currentMode is a ARKitTestViewController property already added in the starter. It represents the current UI state: placeObject value if the object button is selected, or measure value if the measuring button is selected. The switch executes different code depending on the UI state.
        switch self.currentMode {
        case .none:
          break
        // placeObject has an associated string value which represents the path to the 3D model .scn file. You can browse all the 3D models in Models.scnassets.
        case .placeObject(let name):
          // nodeWithModelName(_:) creates a new 3D model SCNNode with the given path name. It’s a helper function provided with the starter project.
          let modelClone = nodeWithModelName(name)
          // Append the node to the objects array provided with the starter.
          self.objects.append(modelClone)
          // Finally, you add your new object node to the SCNNode provided to the delegate method.
          node.addChildNode(modelClone)
        // You’ll implement measuring later.
        case .measure:
          break
        }
      }
    }
  }
  
  func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    DispatchQueue.main.async {
      if let planeAnchor = anchor as? ARPlaneAnchor {
        // Update the child node, which is the plane node you added earlier in renderer(_:didAdd:for:). updatePlaneNode(_:center:extent:) is a function included with the starter that updates the coordinates and size of the plane to the updated values contained in ARPlaneAnchor.
        updatePlaneNode(node.childNodes[0], center: planeAnchor.center, extent: planeAnchor.extent)
      }
    }
  }
  
  func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode,
                for anchor: ARAnchor) {
    guard anchor is ARPlaneAnchor else { return }
    // Removes the plane from the node if the corresponding ARAnchorPlane has been removed. removeChildren(inNode:) was provided with the starter project as well.
    removeChildren(inNode: node)
  }
  
  func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    DispatchQueue.main.async {
      
      // Updates tracking info for each rendered frame.
      self.updateTrackingInfo()
      
      if(!self.isQRCodeFound){
        self.searchQRCode()
      }
      
      // If the dot in the middle hit tests with existingPlaneUsingExtent type, it turns green to indicate high quality hit testing to the user.
      if let _ = self.sceneView.hitTest(
        self.viewCenter,
        types: [.existingPlaneUsingExtent]).first {
        self.crosshair.backgroundColor = UIColor.green
      } else {
        self.crosshair.backgroundColor = UIColor(white: 0.34, alpha: 1)
      }
    }
  }
  
  func session(_ session: ARSession, didFailWithError error: Error) {
    print("ARSession error: \(error.localizedDescription)")
    let message = error.localizedDescription
    
    messageLabel.text = message
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      if self.messageLabel.text == message {
        self.messageLabel.text = ""
      }
    }
  }
  
  // sessionWasInterrupted(_:) is called when a session is interrupted, like when your app is backgrounded.
  func sessionWasInterrupted(_ session: ARSession) {
    print("Session interrupted")
    let message = "Session interrupted"
    
    messageLabel.text = message
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      if self.messageLabel.text == message {
        self.messageLabel.text = ""
      }
    }
  }
  
  func sessionInterruptionEnded(_ session: ARSession) {
    print("Session resumed")
    let message = "Session resumed"
    
    messageLabel.text = message
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      if self.messageLabel.text == message {
        self.messageLabel.text = ""
      }
    }
    
    // When sessionInterruptionEnded(_:) is called, you should remove all your objects and restart the AR session by calling the runSession() method you implemented before. removeAllObjects() is a helper method provided with the starter project.
    removeAllObjects()
    runARSession()
  }
  
}

//adding text at detections objects
//https://github.com/hanleyweng/CoreML-in-ARKit/blob/master/CoreML%20in%20ARKit/ViewController.swift

//rectangle detection
//https://github.com/mludowise/ARKitRectangleDetection

//object tracking
//https://github.com/jeffreybergier/Blog-Getting-Started-with-Vision

//transform coordinates
//https://stackoverflow.com/questions/44944581/how-to-transform-vision-framework-coordinate-system-into-arkit

//Vision Framework with ARkit and CoreMLdra
//https://stackoverflow.com/questions/44976459/vision-framework-with-arkit-and-coreml

//stack overflow question
//https://stackoverflow.com/questions/46151727/apple-vision-image-recognition

//https://stackoverflow.com/questions/44579839/ios-revert-camera-projection
