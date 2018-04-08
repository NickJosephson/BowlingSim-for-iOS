//
//  GameViewController.swift
//  Default Game
//
//  Created by Nicholas Josephson on 2018-03-30.
//  Copyright © 2018 Nicholas Josephson. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit
import AVFoundation

class GameViewController: UIViewController, SCNSceneRendererDelegate, SCNPhysicsContactDelegate {
    var aiming = true
    var rolling = false
    var clearing = false
    var counting = false
    var frameScore = 0
    var score = 0 {
        didSet {
            scoreDisplay?.text = "Score: \(score)"
            scoreDisplay?.setNeedsDisplay()
        }
    }
    var frame = 1
    
    var throwNum = 1 {
        didSet {
            triesDisplay?.text = "Throw \(throwNum)"
            triesDisplay?.setNeedsDisplay()
        }
    }
    
    let maxTries = 2
    
    
    var scene: SCNScene!
    var camera: SCNNode!
    var ball: SCNNode!
    var pins: SCNNode!
    var cleaner: SCNNode!
    var placer: SCNNode!
    var strikeText: SCNNode!
    var spareText: SCNNode!
    var hitHappened: SCNNode!
    
    var scoreDisplay: UILabel!
    var triesDisplay: UILabel!
    
    var rollSound = URL(fileURLWithPath: Bundle.main.path(forResource: "art.scnassets/roll", ofType: "mp3")!)
    var rollAudioPlayer: AVAudioPlayer!
    var hitSound = URL(fileURLWithPath: Bundle.main.path(forResource: "art.scnassets/hit", ofType: "mp3")!)
    var hitAudioPlayer: AVAudioPlayer!
    
    var overlay: UIView!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scoreDisplay = UILabel(frame: CGRect(x: 10, y: 30, width: 400, height: 60))
        scoreDisplay.adjustsFontSizeToFitWidth = true
        scoreDisplay.textColor = UIColor.white
        scoreDisplay.font = UIFont.systemFont(ofSize: 60)
        scoreDisplay.shadowColor = UIColor.black
        scoreDisplay.text = "Score: \(score)"
        self.view.addSubview(scoreDisplay)
        
        triesDisplay = UILabel(frame: CGRect(x: 10, y: 90, width: 400, height: 20))
        triesDisplay.adjustsFontSizeToFitWidth = true
        triesDisplay.textColor = UIColor.white
        triesDisplay.font = UIFont.systemFont(ofSize: 30)
        triesDisplay.shadowColor = UIColor.black
        triesDisplay.text = "Throw \(throwNum)"
        self.view.addSubview(triesDisplay)
        
        overlay = UIView(frame: CGRect(x: -20, y: 125, width: 400, height: 550))
        overlay.backgroundColor = .clear
        
        let glass = UIBlurEffect(style: .light)
        let glassView = UIVisualEffectView(effect: glass)
        glassView.frame = overlay.bounds
        glassView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        overlay.addSubview(glassView)
        //overlay.center = self.view.convert(self.view.center, from:self.view.superview)
        
        let title = UILabel(frame: CGRect(x: 40, y: 20, width: 360, height: 100))
        title.text = "Let's Go Bowling!"
        title.font = UIFont.systemFont(ofSize: 40)
        overlay.addSubview(title)
        
        let text = UITextView(frame: CGRect(x: 35, y: 100, width: 360, height: 300))
        text.text = "Drag from the bowling ball in the direction you want to throw. The longer your drag, the more powerfull the throw! (The physics are tuned for fun more than realism 😄)\n\nAfter two throws or a score of 10, the pins will be cleared.\n\nGet a strike or spare for a fun display.\n\nGood luck and thank you for playing!"
        text.font = UIFont.systemFont(ofSize: 20)
        text.backgroundColor = UIColor.clear
        overlay.addSubview(text)
        
        
        let startButton = UIButton(frame: CGRect(x: 150, y: 475, width: 100, height: 20))
        startButton.setTitle("Start", for: .normal)
        startButton.addTarget(self, action: #selector(startClicked), for: .touchUpInside)
        startButton.titleLabel?.font = UIFont.systemFont(ofSize: 40)
        
        overlay.addSubview(startButton)
        
        self.view.addSubview(overlay)
        //overlay.center = self.view.convert(self.view.center, from:self.view.superview)
        
        
        // create a new scene
        let scene = SCNScene(named: "art.scnassets/ally.scn")!
        
        ball = scene.rootNode.childNode(withName: "ball", recursively: true)!
        camera = scene.rootNode.childNode(withName: "mainCamera", recursively: true)!
        pins = scene.rootNode.childNode(withName: "mainPins", recursively: true)!
        cleaner = scene.rootNode.childNode(withName: "cleaner", recursively: true)!
        placer = scene.rootNode.childNode(withName: "placer", recursively: true)!
        strikeText = scene.rootNode.childNode(withName: "strikeText", recursively: true)!
        spareText = scene.rootNode.childNode(withName: "spareText", recursively: true)!
        hitHappened = scene.rootNode.childNode(withName: "hitHappened", recursively: true)!
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        ambientLightNode.light!.intensity = 50
        scene.rootNode.addChildNode(ambientLightNode)
        
        // retrieve the SCNView
        let scnView = self.view as! SCNView
        
        // set the scene to the view
        scnView.scene = scene
        scnView.delegate = self
        scene.physicsWorld.contactDelegate = self
        
        // allows the user to manipulate the camera
        scnView.allowsCameraControl = false
        
        // show statistics such as fps and timing information
        scnView.showsStatistics = true
        
        // add gesture recognizers
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)
        
        resetCamera()
        do {
            try rollAudioPlayer = AVAudioPlayer(contentsOf: rollSound)
            rollAudioPlayer.prepareToPlay()
            try hitAudioPlayer = AVAudioPlayer(contentsOf: hitSound)
            hitAudioPlayer.prepareToPlay()
        } catch {
            print(error)
        }
    }
    
    @objc
    func startClicked(sender: UIButton)
    {
        overlay.removeFromSuperview()
    }
    
    
    var pinHit = false
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        if rolling && !pinHit {
            let nodeAName = contact.nodeA.name
            let nodeBName = contact.nodeB.name
            
            if nodeAName != nil && nodeBName != nil {
                if nodeAName! == "ball" && nodeBName! == "Pin" {
                    hitHappened.isHidden = false
                } else if nodeAName! == "Pin" && nodeBName! == "ball"{
                    hitHappened.isHidden = false
                }
            }
        }
    }
    
    var startTime: TimeInterval?
    
    func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        if rolling {
            if startTime != nil {
                if (time - startTime!) > 10 || ball.position.y < -0.5 || ball.presentation.position.y < -0.5 {
                    startTime = nil
                    rolling = false
                    counting = true
                    pinHit = false
                } else {
                    camera.look(at: ball.presentation.position)
                    let ballOffset = ball.presentation.position.z + 4
                    if ballOffset > -6 {
                        camera.position.z = ballOffset
                    }
                    
                    if !hitHappened.isHidden {
                        pinHit = true
                        hitAudioPlayer?.play()
                        hitHappened.isHidden = true
                    }
                    
                }
            } else {
                startTime = time
            }
        } else if counting {
            if startTime != nil {
                if (time - startTime!) > 5 {
                    let newFrameScore = calculateScore()
                    DispatchQueue.main.async {
                        self.score += (newFrameScore - self.frameScore)
                        self.frameScore = newFrameScore
                    }
                    
                    resetBall()
                    counting = false
                    startTime = nil
                    if throwNum == 1 && frameScore == 10 {
                        strikeText.isHidden = false
                        clearing = true
                        resetCamera()
                    } else if throwNum == 2 && frameScore == 10 {
                        spareText.isHidden = false
                        clearing = true
                        resetCamera()
                    } else if throwNum == maxTries || frameScore == 10  {
                        lookAtPins()
                        clearing = true
                    } else {
                        aiming = true
                        resetCamera()
                        DispatchQueue.main.async {
                            self.throwNum += 1
                        }
                    }
                }
            } else {
                startTime = time
            }
        } else if clearing {
            moveCleanerAndPlacer()
        }
    }
    
    
    var cleanerDown = true
    var cleanerBack = false
    var cleanerforward = false
    var cleanerUp = false
    var placerDown = false
    var placerUp = false
    
    func moveCleanerAndPlacer() {
        if cleanerDown {
            if cleaner.position.y > 1 {
                cleaner.position.y -= 0.05
            } else {
                cleanerDown = false
                cleanerBack = true
            }
        } else if cleanerBack { //-17.55
            if cleaner.position.z > -20 {
                cleaner.position.z -= 0.05
            } else {
                cleanerBack = false
                cleanerforward = true
            }
        } else if cleanerforward { //-17.55
            if cleaner.position.z < -17.55 {
                cleaner.position.z += 0.05
            } else {
                cleanerforward = false
                cleanerUp = true
            }
        }else if cleanerUp {
            if cleaner.position.y < 2.25 {
                cleaner.position.y += 0.05
            } else {
                cleanerDown = true
                cleanerUp = false
                clearing = false
                aiming = true
                resetPins()
                resetCamera()
                strikeText.isHidden = true
                spareText.isHidden = true
                DispatchQueue.main.async {
                    self.throwNum = 1
                }
            }
        }
    }
    
    func lookAtPins() {
        resetCamera()
        camera.position.z = -6
        camera.look(at: pins.position)
    }
    
    
    func resetPins() {
        (pins as! SCNReferenceNode).unload()
        (pins as! SCNReferenceNode).load()
    }
    
    func resetBall() {
        ball.removeAllAnimations()
        ball.removeAllActions()
        ball.physicsBody?.velocity = SCNVector3(x: 0, y: 0, z: 0)
        ball.physicsBody?.angularVelocity = SCNVector4(x: 0, y: 0, z: 0, w: 0)
        ball.position = SCNVector3(x: 0, y: 0.3, z: 13)
    }
    
    func resetCamera() {
        camera.position = SCNVector3(x: 0, y: 3, z: 21)
        camera.eulerAngles = SCNVector3(x: -20, y: 0, z: 0)
        camera.look(at: pins.position)
    }
    
    func calculateScore() -> Int {
        var total = 0
        
        for pin in pins.childNodes {
            print(pin.childNodes[0].worldPosition.y)
            print(pin.childNodes[0].presentation.worldPosition.y)
            
            if pin.childNodes[0].worldPosition.y < 0.601 || pin.childNodes[0].presentation.worldPosition.y < 0.601 {
                total += 1
            }
        }
        
        return total
    }
    
    var startLocation = CGPoint(x: 0, y: 0)
    
    @objc
    func handlePan(_ gestureRecognizer:UIPanGestureRecognizer) {
        let scnView = self.view as! SCNView
        
        switch gestureRecognizer.state {
        case .began:
            startLocation = gestureRecognizer.location(in: scnView)
        case .ended:
            let stopLocation = gestureRecognizer.location(in: scnView)
            let dx = stopLocation.x - startLocation.x;
            let dy = stopLocation.y - startLocation.y;
            //let distance = sqrt(dx*dx + dy*dy );
            let hitResults = scnView.hitTest(startLocation, options: [:])
            // check that we clicked on at least one object
            if aiming && hitResults.count > 0 {
                // retrieved the first clicked object
                let result = hitResults[0]
                if (result.node.name == "ball") {
                    result.node.physicsBody?.applyForce(SCNVector3(x: Float(dx) * 0.33, y: 0, z: Float(dy) * 0.33), at: SCNVector3(x: 0, y: 0.25, z: 0) , asImpulse: true)
                    //result.node.physicsBody?.applyTorque(SCNVector3(x: Float(dx) * slider.value, y: 0, z: 0), asImpulse: false)
                    //result.node.physicsBody?.velocity = SCNVector3(x: Float(dx)/10, y: 0, z: Float(dy)/10)
                    rollAudioPlayer?.play()
                    aiming = false
                    rolling = true
                } else {
                    ball.position.x += Float(dx)/1000
                }
            }
        default:
            break
        }
    }
    
}
