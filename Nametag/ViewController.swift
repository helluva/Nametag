//
//  ViewController.swift
//  Nametag
//
//  Created by Cal Stephens on 10/14/17.
//  Copyright © 2017 Helluva. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var faceRectView: UIView!
    @IBOutlet weak var faceLabel: UILabel!
    
    let speechController = SpeechController()
    
    var frameHistory = [CGRect]()
    var averageBounds: CGRect!
    
    var mostRecentFaceImage: (date: Date, image: UIImage)?
    
    var bottomIndicatorView: OverlayView?
    
    var faceBeingBuilt: Face?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
                
        faceRectView.isHidden = true
        faceRectView.layer.borderColor = UIColor.red.cgColor
        faceRectView.layer.borderWidth = 5
        faceLabel.isHidden = true
        
        speechController.setup()
        speechController.delegate = self
    }
    
    @IBAction func swipeGestureRecognizer(_ sender: UISwipeGestureRecognizer) {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "CollectionViewController") as! CollectionViewController
        viewController.modalPresentationStyle = .overCurrentContext
        self.present(viewController, animated: false, completion: nil)
    }
    
    func preflightPresentationAnimation() {
        
    }
    
    func performPresentationAnimation() {
        
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = AROrientationTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: - VNDetectFaceRectanglesRequest
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let pixelBuffer = sceneView.session.currentFrame?.capturedImage else {
            return
        }
        
        //DispatchQueue.global(qos: .background).async {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let temporaryContext = CIContext(options: nil)
            let videoImage = temporaryContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer)))
            
            guard let imageFromFeed = videoImage?.rotate() else {
                return
            }
            
            let request = VNDetectFaceRectanglesRequest(completionHandler: self.bindImageToFaceDetectionHandler(imageFromFeed))
            let requestHandler = VNImageRequestHandler(cgImage: imageFromFeed, orientation: .up, options: [:])
            try? requestHandler.perform([request])
        //}
    }

    func bindImageToFaceDetectionHandler(_ image: CGImage) -> ((VNRequest, Error?) -> Void) {
        
        return { (request: VNRequest, error: Error?) -> Void in
            guard let observations = request.results as? [VNFaceObservation] else {
                fatalError("unexpected result type!")
            }
            
            self.averageBounds = self.frameHistory.average
            
            let largestFace = observations.max(by: { (face1: VNFaceObservation, face2: VNFaceObservation) -> Bool in
                let face1Area = face1.boundingBox.size.height * face1.boundingBox.size.width
                let face2Area = face2.boundingBox.size.height * face2.boundingBox.size.width
                return face1Area < face2Area
            })
            
            if let largestFace = largestFace {
                self.updateForFace(largestFace, in: image)
            } else if self.frameHistory.count > 0 {
                self.frameHistory.remove(at: 0)
            }
            
            DispatchQueue.main.async {
                self.setDisplayLabels()
            }
        }
    }
    
    func updateForFace(_ face: VNFaceObservation, in image: CGImage) {
        
        //make sure face is large enough to be in foreground
        guard face.boundingBox.size.width >= 0.33 else {
            if self.frameHistory.count > 0 {
                self.frameHistory.remove(at: 0)
            }
            
            return
        }
        
        DispatchQueue.main.async {
            let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -self.view.frame.height)
            let translate = CGAffineTransform.identity.scaledBy(x: self.view.frame.width, y: self.view.frame.height)
            let facebounds = face.boundingBox.applying(translate).applying(transform)
            
            self.frameHistory.append(facebounds)
            
            if self.frameHistory.count > 5 {
                self.frameHistory.remove(at: 0)
            }
            
            if self.frameHistory.count > 4 {
                self.faceRectView.frame = self.averageBounds
            }
            
            let croppedFace = image.crop(rect: facebounds, padding: 50)
            self.fetchVectorForFace(in: UIImage(cgImage: croppedFace))
        }
        
    }
    
    // MARK: - Calculate vector for face
    
    private var previousVectorRequestDate: Date? = nil
    private let minimumVectorRequestInterval = TimeInterval(1.0)
    
    func fetchVectorForFace(in faceImage: UIImage) {
        self.mostRecentFaceImage = (Date(), faceImage)
        
        if let previousVectorRequestDate = self.previousVectorRequestDate,
            Date().timeIntervalSince(previousVectorRequestDate) < minimumVectorRequestInterval
        {
            return
        }
        
        previousVectorRequestDate = Date()
        
        if let faceBeingBuilt = self.faceBeingBuilt {
            NametagServerClient.fetchFaceAnalysisResult(image: faceImage, completion: { vector in
                guard let vector = vector else {
                    return
                }
                
                faceBeingBuilt.addVector(vector)
            })
        }
        
        
    }
    
    
    // MARK: AR Overlays
    
    func setDisplayLabels() {
        self.faceRectView.isHidden = self.frameHistory.count <= 4
        self.renderFaceLabel(faceBounds: averageBounds, name: "Cal", display: self.frameHistory.count > 2)
    }
    
    func renderFaceLabel(faceBounds: CGRect?, name: String?, display: Bool) {
        faceLabel.isHidden = !display
        if display {
            let strokeTextAttributes: [NSAttributedStringKey : Any] = [
                NSAttributedStringKey.strokeColor : UIColor.black,
                NSAttributedStringKey.foregroundColor : UIColor.white,
                NSAttributedStringKey.strokeWidth : -2.0,
                ]
            
            faceLabel.attributedText = NSAttributedString(string: name!, attributes: strokeTextAttributes)
            
            let labelBounds = CGRect(
                x: faceBounds!.origin.x,
                y: faceBounds!.origin.y - faceBounds!.size.height,
                width: faceBounds!.size.width,
                height: faceBounds!.size.width)
            faceLabel.frame = labelBounds
        }
    }
    
    // MARK: Static overlays
    
    func showBottomIndicator(text: String) {
        removeCenteredLoadingIndicator(animated: false)
        
        let indicator = OverlayView(
            text: text,
            showLoadingIndicator: false,
            textColor: .black,
            textSize: 17)
        
        view.addSubview(indicator)
        indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        indicator.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10).isActive = true
        
        if self.bottomIndicatorView == nil {
            indicator.alpha = 0
            indicator.playAppearAnimation()
        }
        
        self.bottomIndicatorView = indicator
    }
    
    func removeCenteredLoadingIndicator(animated: Bool) {
        guard let existingIndicator = self.bottomIndicatorView else {
            return
        }
        
        if animated {
            existingIndicator.playDisappearAnimation(then: {
                existingIndicator.removeFromSuperview()
            })
        } else {
            existingIndicator.removeFromSuperview()
        }
        
        bottomIndicatorView = nil
    }
    
    
}

// MARK: SpeechControllerDelegate

extension ViewController: SpeechControllerDelegate {
    
    func speechController(_ controller: SpeechController, didDetectIntroductionWithName name: String) {
        
        if let mostRecentFaceImage = self.mostRecentFaceImage,
            Date().timeIntervalSince(mostRecentFaceImage.date) < 2
        {
            showBottomIndicator(text: "Detected \(name)")
            
            let newFace = Face(name: name, image: mostRecentFaceImage.image)
            self.faceBeingBuilt = newFace
            NTFaceDatabase.addFace(newFace)
        }
        
        
    }
    
}
