//
//  ViewController.swift
//  Flight Tracker
//
//  Created by Maxwell Hubbard on 10/19/19.
//  Copyright © 2019 Maxwell Hubbard. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import CoreLocation
import WebKit
import MapboxSceneKit

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(rgb: Int) {
        self.init(
            red: (rgb >> 16) & 0xFF,
            green: (rgb >> 8) & 0xFF,
            blue: rgb & 0xFF
        )
    }
}

extension UIView {
    func fadeTo(_ alpha: CGFloat, duration: TimeInterval? = 0.3) {
        DispatchQueue.main.async {
            UIView.animate(withDuration: duration != nil ? duration! : 0.3) {
                self.alpha = alpha
            }
        }
    }
    
    func fadeIn(_ duration: TimeInterval? = 0.3) {
        fadeTo(1.0, duration: duration)
    }
    func fadeOut(_ duration: TimeInterval? = 0.3) {
        fadeTo(0.0, duration: duration)
    }
}

protocol PropertyStoring {
    associatedtype T
    func getAssociatedObject(_ key: UnsafeRawPointer!, defaultValue: T) -> T
}
extension PropertyStoring {
    func getAssociatedObject(_ key: UnsafeRawPointer!, defaultValue: T) -> T {
        guard let value = objc_getAssociatedObject(self, key) as? T else {
            return defaultValue
        }
        return value
    }
}

extension UIView : PropertyStoring{
    typealias T = UIView
    private struct CustomProperties {
        static var toggleState = UIView()
    }
    
    var container: UIView {
        get {
            return getAssociatedObject(&CustomProperties.toggleState, defaultValue: CustomProperties.toggleState)
        }
        set {
            return objc_setAssociatedObject(self, &CustomProperties.toggleState, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    func showActivityIndicatory() {
        if container != nil {
            container.removeFromSuperview()
        }
        container = UIView()
        container.frame = frame
        container.center = center
        
        
        container.backgroundColor = UIColor(rgb: 0xffffff).withAlphaComponent(0.3)
        
        let loadingView: UIView = UIView()
        loadingView.frame = CGRect(x:0, y:0, width:80, height:80)
        loadingView.center = center
        loadingView.backgroundColor = UIColor(rgb: 0x444444).withAlphaComponent(0.7)
        loadingView.clipsToBounds = true
        loadingView.layer.cornerRadius = 10
        
        let actInd: UIActivityIndicatorView = UIActivityIndicatorView()
        actInd.frame = CGRect(x:0.0, y:0.0, width:40.0, height:40.0);
        actInd.style =
            UIActivityIndicatorView.Style.whiteLarge
        actInd.center = CGPoint(x:loadingView.frame.size.width / 2,
                                y:loadingView.frame.size.height / 2);
        loadingView.addSubview(actInd)
        container.addSubview(loadingView)
        addSubview(container)
        actInd.startAnimating()
    }
}

extension SCNNode {
    
    convenience init(named name: String) {
        self.init()
        
        guard let scene = SCNScene(named: name) else {
            return
        }
        
        for childNode in scene.rootNode.childNodes {
            addChildNode(childNode)
        }
    }
    
}

extension FloatingPoint {
    func toRadians() -> Self {
        return self * .pi / 180
    }
    
    func toDegrees() -> Self {
        return self * 180 / .pi
    }
}

extension SCNVector3 {
    static func positionFromTransform(_ transform: matrix_float4x4) -> SCNVector3 {
        return SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
}

extension SCNNode {
    func hasAncestor(_ node: SCNNode) -> Bool {
        if self === node {
            return true // this is the node you're looking for
        }
        if self.parent == nil {
            return false // target node can't be a parent/ancestor if we have no parent
        }
        if self.parent === node {
            return true // target node is this node's direct parent
        }
        // otherwise recurse to check parent's parent and so on
        return self.parent!.hasAncestor(node)
    }
}

class ViewController: UIViewController, ARSCNViewDelegate, WKNavigationDelegate, UITextFieldDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    var geoNode: SCNNode!
    var terrain: TerrainNode!
    
    var isRotating: Bool = false
    
    var inTerrain: Bool = false
    
    @IBOutlet weak var topVisView: UIVisualEffectView!
    
    @IBOutlet weak var flightLabel: UILabel!
    
    @IBOutlet weak var bottomVisView: UIVisualEffectView!
    
  
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var searchField: UITextField!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        topVisView.alpha = 1
        flightLabel.alpha = 0
        bottomVisView.alpha = 0
        
        searchField.delegate = self
        
        topVisView.layer.cornerRadius = 5
        topVisView.layer.masksToBounds = true
        
        self.webView.navigationDelegate = self
        
        let rotateGesture = UIRotationGestureRecognizer(target: self, action: #selector(rotateNode(_:)))
        view.addGestureRecognizer(rotateGesture)
        
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(scaleObject(gesture:))))
        
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(leaveTerrain))
        swipeGesture.direction = .right
        view.addGestureRecognizer(swipeGesture)
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
        
        
        
        // Create a new scene
        let scene = SCNScene()
        
        geoNode = SCNNode(named: "art.scnassets/Earth_Three+Views.dae")
        
        
        
        // Set the scene to the view
        sceneView.scene = scene
        
        sceneView.scene.rootNode.addChildNode(self.geoNode)
        
        geoNode.pivot = SCNMatrix4MakeTranslation(0, 0, 0)
        //self.geoNode.scale = SCNVector3(0.25, 0.25, 0.25)
        geoNode.position = SCNVector3(0, 0, -800) // X - Left(neg) Right(pos), Z - FWD(neg) BACK(pos)
        
        getFlightData(search: "")
        
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { timer in
            if !self.inTerrain {
                self.getFlightData(search: self.searchField.text!)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        // Run the view's session
        sceneView.session.run(configuration)
        
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    // MARK: - ARSCNViewDelegate
    

    var flights: [String : Flight] = [String:Flight]()
    var airplaneNodes: [SCNNode : Flight] = [SCNNode : Flight]()
    
    func getFlightData(search: String) {
        
        for nodes in Array(self.airplaneNodes.keys) {
            nodes.removeAllActions()
            nodes.removeFromParentNode()
        }
        
        flights.removeAll()
        
        self.airplaneNodes.removeAll()
        
        let task = URLSession.shared.dataTask(with: URL(string: "https://opensky-network.org/api/states/all")!) {
            (data, response, error) in
            
            if error == nil {
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options: []) as? [String : Any]
                    
                    let flightsArray: [[AnyObject?]] = json!["states"]! as! [[AnyObject?]]
                    
                    // TODO: Make flights from class and add to array / dictionaries that could sort by airline / origin / destination / etc
                    
                    
                    print("Starting Flight Load")
                    for(_, item) in flightsArray.enumerated() {
                        
                        
                        
                        if (item[1] != nil && (item[1] as! String).count > 3 && item[5] != nil && item[6] != nil) {
                            
                            let callsign = (item[1] as! String)
                            
                            let start = String.Index(utf16Offset: 0, in: callsign)
                            let end = String.Index(utf16Offset: 3, in: callsign)
                            let substring = String(callsign[start..<end])
                            
                            
                            let airline = Files.airlines[substring]
                            
                            if airline != nil && search == "" || airline != nil && airline!.contains(search) {
                                
                                self.flights[(item[0] as! String)] = Flight(data: item)
                                
                                if self.airplaneNodes.keys.count < 30 {
                                    self.generateAirplaneNode(flight: self.flights[(item[0] as! String)]!)
                                }
                                
                                
                            }
                        }
                    }
                    
                                        
                    print("Done!")
                    
                    // Generate nodes based on filter/search and display
                    
                    
                    
                } catch {
                    
                }
                
                //print(String(data: data!, encoding: .utf8))
            } else {
                print("ERROR: ", error!)
            }
        }
        task.resume()
        
    }
    
    func loadAirports(callsign: String) {
        
        let string = "https://flightaware.com/live/flight/" + callsign
        
        self.webView.load(URLRequest(url: URL(string: string)!))
        
    }
    
    func generateAirplaneNode(flight: Flight) {
        
        
        let node = SCNNode(named: "art.scnassets/plane.dae")
        
        
        
        // Globe size: 505.033
        node.scale = geoNode.scale
        
        let radius = 252.5165
        let lat = flight.lat!
        let lon = flight.lon!
        
        let phi   = (90.0 - lat) * (Double.pi / 180.0)
        let theta = (lon + 180.0) * (Double.pi / 180.0)
        let x = -((radius) * sin(phi) * cos(theta))
        let z = ((radius) * sin(phi) * sin(theta))
        let y = ((radius) * cos(phi))
        
        
        //lat: North/South +90/-90
        //Lon: East/West -180/+180
        
        
        
        // Translate node
        node.position = SCNVector3(x, y, z)
        
        // Scale node
        node.scale = SCNVector3(0.25, 0.25, 0.25)
        
        
        node.name = "PLANE"
        
        airplaneNodes[node] = flight
        
        geoNode.addChildNode(node)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        getFlightData(search: textField.text!)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    
    @objc func scaleObject(gesture: UIPinchGestureRecognizer) {
        
        if !isRotating{
            
            var nodeToScale = geoNode
            
            if inTerrain {
                nodeToScale = terrain
            }
            
            if gesture.state == .changed {
                
                let pinchScaleX: CGFloat = gesture.scale * CGFloat((nodeToScale!.scale.x))
                let pinchScaleY: CGFloat = gesture.scale * CGFloat((nodeToScale!.scale.y))
                let pinchScaleZ: CGFloat = gesture.scale * CGFloat((nodeToScale!.scale.z))
                nodeToScale!.scale = SCNVector3Make(Float(pinchScaleX), Float(pinchScaleY), Float(pinchScaleZ))
                gesture.scale = 1
                
            }
            if gesture.state == .ended { }
        }
    }
    
    var currentAngleY: Float = 0.0
    @objc func rotateNode(_ gesture: UIRotationGestureRecognizer){
        
        
        var currentNode = geoNode!
        
        if inTerrain {
            currentNode  = terrain
        }
        
        //1. Get The Current Rotation From The Gesture
        let rotation = Float(gesture.rotation)
        
        //2. If The Gesture State Has Changed Set The Nodes EulerAngles.y
        if gesture.state == .changed{
            isRotating = true
            currentNode.eulerAngles.y = currentAngleY + rotation
        }
        
        //3. If The Gesture Has Ended Store The Last Angle Of The Cube
        if(gesture.state == .ended) {
            currentAngleY = currentNode.eulerAngles.y
            isRotating = false
        }
        
    }
    
    @objc func leaveTerrain() {
        
        if inTerrain {
                        
            self.searchField.text = ""
            
            getFlightData(search: self.searchField.text!)
            
            
            
            UIView.animate(withDuration: 1.5, animations: {
                
                self.flightLabel.alpha = 0
                self.searchField.alpha = 0.9
                self.bottomVisView.alpha = 0
                
                
            })
            self.terrain.runAction(SCNAction.fadeOut(duration: 2), completionHandler: {
                self.terrain.removeFromParentNode()
            })
            self.geoNode.runAction(SCNAction.fadeIn(duration: 2))
            
            inTerrain = false
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
        let touch = touches.first!
        if(touch.view == self.sceneView){
            let viewTouchLocation:CGPoint = touch.location(in: sceneView)
            guard let result = sceneView.hitTest(viewTouchLocation, options: nil).first else {
                return
            }
            
            
            var n: SCNNode? = result.node
            while n != nil {
                if n!.name != nil && n!.name == "PLANE" {
                    break
                }
                n = n!.parent
            }
            
            
            
            if n != nil {
                
                let flight = airplaneNodes[n!]
                
                flightLabel.text =  flight!.airline + " #" + flight!.flightNum
                
                loadAirports(callsign: flight!.callsign)
                
                
                Timer.scheduledTimer(withTimeInterval: 5, repeats: false, block: {_ in 
                    self.addTerrain(flight: flight!)
                })
                
                
                
                UIView.animate(withDuration: 1.5, animations: {
                    
                    self.flightLabel.alpha = 1
                    self.searchField.alpha = 0
                    self.bottomVisView.alpha = 1
                    
                })
                
            }
            
        }
    }
    
    
    func addTerrain(flight: Flight) {
        
        let terrainNode = TerrainNode(minLat: flight.lat - 0.4, maxLat: flight.lat + 0.4,
                                      minLon: flight.lon - 0.4, maxLon: flight.lon + 0.4)
        
        
        let scale = Float(0.0003)
        terrainNode.transform = SCNMatrix4MakeScale(scale, scale, scale)
        terrainNode.position = SCNVector3(0, 0, 0)
        terrainNode.geometry?.materials = defaultMaterials()
        
        terrain = terrainNode
        terrain.opacity =  0
        self.sceneView.scene.rootNode.addChildNode(terrain)
        
        
        
        terrainNode.fetchTerrainAndTexture(minWallHeight: 100, multiplier: 4, enableDynamicShadows: true, textureStyle: "mapbox/satellite-v9", heightProgress: nil, heightCompletion: { fetchError in
            if let fetchError = fetchError {
                NSLog("Terrain load failed: \(fetchError.localizedDescription)")
            } else {
                NSLog("Terrain load complete")
                
                self.view.container.removeFromSuperview()
                
                self.inTerrain = true
                
                //self.sceneView!.scene.rootNode.replaceChildNode(self.geoNode, with: terrainNode)
                
                self.addPlaneToTerrain(flight: flight)
                
                self.terrain.runAction(SCNAction.fadeIn(duration: 2))
                self.geoNode.runAction(SCNAction.fadeOut(duration: 2))
                
                
            }
        }, textureProgress: nil) { image, fetchError in
            if let fetchError = fetchError {
                NSLog("Texture load failed: \(fetchError.localizedDescription)")
            }
            if image != nil {
                NSLog("Texture load complete")
                terrainNode.geometry?.materials[4].diffuse.contents = image
                
                terrainNode.position = SCNVector3(0, -5, -15)
            }
        }

        sceneView!.isUserInteractionEnabled = true
    }
    
    func addPlaneToTerrain(flight:  Flight) {
        
        let node = SCNNode(named: "art.scnassets/plane.dae")
        
        let tempLocation = CLLocation(latitude: flight.lat, longitude: flight.lon)
        node.position = terrain.positionForLocation(tempLocation)
        node.position.y += 5000
        node.scale = SCNVector3(x: 110, y: 110, z: 110)
        
        terrain.addChildNode(node)
        
       
        
        //node.scale = SCNVector3(20, 20, 20)
    }
    
    private func defaultMaterials() -> [SCNMaterial] {
        let groundImage = SCNMaterial()
        groundImage.diffuse.contents = UIColor.darkGray
        groundImage.name = "Ground texture"
        
        let sideMaterial = SCNMaterial()
        sideMaterial.diffuse.contents = UIColor.darkGray
        //TODO: Some kind of bug with the normals for sides where not having them double-sided has them not show up
        sideMaterial.isDoubleSided = true
        sideMaterial.name = "Side"
        
        let bottomMaterial = SCNMaterial()
        bottomMaterial.diffuse.contents = UIColor.black
        bottomMaterial.name = "Bottom"
        
        return [sideMaterial, sideMaterial, sideMaterial, sideMaterial, groundImage, bottomMaterial]
    }
}
