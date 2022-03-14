	  //
	  //  PreviewView.swift
	  //  Temp
	  //
	  //  Created by René Fokkema on 12/08/2021.
	  //

import UIKit
import AVFoundation

class PreviewView: UIView {

			 //	  var videoPreviewLayer: AVCaptureVideoPreviewLayer {
			 //			 guard let layer = layer as? AVCaptureVideoPreviewLayer else {
			 //					fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
			 //			 }
			 //			 return layer
			 //	  }
			 //
			 //	  var session: AVCaptureSession? {
			 //			 get {
			 //					return videoPreviewLayer.session
			 //			 }
			 //			 set {
			 //					videoPreviewLayer.session = newValue
			 //			 }
			 //	  }
			 //
			 //	  override class var layerClass: AnyClass {
			 //			 return AVCaptureVideoPreviewLayer.self
			 //	  }

	  var controller: CameraViewController!

	  init(frame: CGRect, controller: CameraViewController) {

			 var frame = frame
			 frame.origin.x -= frame.width/2
			 frame.origin.y -= frame.height/2

			 super.init(frame: frame)

			 startPosition = center
			 self.controller = controller

			 scaleVelocity = CGFloat.random(in: -30...20)
			 rotationVelocity = CGFloat.random(in: 2...8)
			 panVelocity = CGPoint(x: CGFloat.random(in: -100...475), y: CGFloat.random(in: -100...912))

			 backgroundColor = .random

			 tapGR = UITapGestureRecognizer(target: self, action: #selector(bringToTop))
			 //tapGR.numberOfTapsRequired = 1
			 tapGR.require(toFail: controller.newViewTap)
			 addGestureRecognizer(tapGR)

			 // superview?.superview?.backgroundColor = .random

			 // setupGestureRecognizers()

			 _ = Timer.scheduledTimer(withTimeInterval: Double.random(in: 1...4), repeats: false, block: { _ in
					_ = self.endTransform(nil)
			 })

	  }

	  var scaleGR:UIPinchGestureRecognizer!
	  var rotateGR:UIRotationGestureRecognizer!
	  var moveGR:UIPanGestureRecognizer!
	  var tapGR:UITapGestureRecognizer!

	  required init?(coder: NSCoder) {
			 super.init(coder: coder)
	  }

	  private func setupGestureRecognizers() {

			 scaleGR = UIPinchGestureRecognizer(target: self, action: #selector(scaleView))
					//scaleGR.requiresExclusiveTouchType = true
			 scaleGR.delegate = self
			 addGestureRecognizer(scaleGR)

			 rotateGR = UIRotationGestureRecognizer(target: self, action: #selector(rotateView))
					//rotateGR.requiresExclusiveTouchType = true
			 rotateGR.delegate = self
			 addGestureRecognizer(rotateGR)

			 moveGR = UIPanGestureRecognizer(target: self, action: #selector(moveView))
			 moveGR.minimumNumberOfTouches = 1
					//moveGR.requiresExclusiveTouchType = true
			 moveGR.delegate = self
			 addGestureRecognizer(moveGR)
	  }

	  @objc private func bringToTop() {
			 // superview?.bringSubviewToFront(self)

			 var goodBye = endTransform(nil)
			 while !goodBye {
					scaleVelocity = CGFloat.random(in: -30...20)
					rotationVelocity = CGFloat.random(in: 2...8)
					panVelocity = CGPoint(x: CGFloat.random(in: -100...475), y: CGFloat.random(in: -100...912))

					// print("Trying to end transform.")
					goodBye = endTransform(nil)
			 }
	  }

	  var startPosition: CGPoint!
	  var startTransform: CGAffineTransform!
	  var newTranslation = CGPoint(x: 0.0, y: 0.0)
	  var newScale: CGFloat = 1.0
	  var newRotation: CGFloat = 0.0
	  var firstRecognizer: UIGestureRecognizer! = nil
	  var scaleVelocity = 1.0, rotationVelocity = 0.0, panVelocity = CGPoint(x: 0.0, y: 0.0)

	  @objc private func scaleView(sender: UIPinchGestureRecognizer) {

			 switch sender.state {
			 case .began:
					if firstRecognizer == nil {
						  animator.stopAnimation(true)
						  firstRecognizer = sender
						  startTransform = transform
					}

			 case .changed:
					newScale = sender.scale
					scaleVelocity = sender.velocity
					if sender == firstRecognizer {
						  transform = startTransform.scaledBy(x: newScale, y: newScale).rotated(by: newRotation)
						  center.x  = startPosition.x + newTranslation.x
						  center.y  = startPosition.y + newTranslation.y
					}

			 case .ended:
					// scaleVelocity = sender.velocity
					_ = endTransform(sender)

			 default: break
			 }

	  }

	  @objc private func rotateView(_ sender: UIRotationGestureRecognizer) {

			 switch sender.state {
			 case .began:
					if firstRecognizer == nil {
						  animator.stopAnimation(true)
						  firstRecognizer = sender
						  startTransform = transform
					}

			 case .changed:
					newRotation = sender.rotation
					rotationVelocity = sender.velocity
					if sender == firstRecognizer {
						  transform = startTransform.rotated(by: newRotation).scaledBy(x: newScale, y: newScale)
						  center.x  = startPosition.x + newTranslation.x
						  center.y  = startPosition.y + newTranslation.y
					}

			 case .ended:
					// rotationVelocity = sender.velocity
					endTransform(sender)

			 default: break
			 }
	  }

	  @objc private func moveView(sender: UIPanGestureRecognizer) {

			 switch sender.state {

			 case .began:
					startPosition = center
					if firstRecognizer == nil {
						  animator.stopAnimation(true)
						  firstRecognizer = sender
						  startTransform = transform
					}

			 case .changed:
					// panVelocity = sender.velocity(in: superview)
					newTranslation = sender.translation(in: superview)
					if sender == firstRecognizer {
						  transform = startTransform.rotated(by: newRotation).scaledBy(x: newScale, y: newScale)
						  center.x  = startPosition.x + newTranslation.x
						  center.y  = startPosition.y + newTranslation.y
					}

			 case .ended:
					panVelocity = sender.velocity(in: superview)
					endTransform(sender)

			 default: break
			 }
	  }

	  var animator = UIViewPropertyAnimator(duration: 1.0, curve: .linear, animations: nil)

	  private func endTransform(_ sender: UIGestureRecognizer?) -> Bool {
			 guard sender == firstRecognizer, scaleVelocity != 0.0, rotationVelocity != 0.0
			 else { return false }

			 for i in 0 ... 0 {
					// print("Kijk, hier is i:", String(describing: i))
			 }

			 firstRecognizer = nil

			 animator.isInterruptible = false
			 animator.isUserInteractionEnabled = false

			 // rotationVelocity = 3 // rotationVelocity < 0.1 ? 100.0 : rotationVelocity
			 if scaleVelocity < 0 { scaleVelocity = 1 / abs(scaleVelocity) }
			 if scaleVelocity < 0.5 { scaleVelocity = 0.001 }

			 rotationVelocity = abs(rotationVelocity)

			 animator.addAnimations({
					self.transform = self.transform.scaledBy(x: self.scaleVelocity, y: self.scaleVelocity).rotated(by: self.rotationVelocity)
					self.center.x  = self.center.x + self.panVelocity.x
					self.center.y  = self.center.y + self.panVelocity.y
			 })

			 animator.addCompletion({ _ in

					if self.frame.minX < 0 && self.frame.maxX > 375
					&& self.frame.minY < 0 && self.frame.maxY > 812 {
						  self.controller.view.backgroundColor = self.backgroundColor
						  if let myIndex = self.superview?.subviews.firstIndex(of: self),
								   myIndex > 1 {

										// print("\n myIndex:", myIndex)

								 for i in (0...myIndex-1).reversed()  {

										// print("\n Verwijderen:", i)

											  if let view = self.superview?.subviews[i] {
													 view.removeFromSuperview()
											  }
										}
						  }
					}
					self.removeFromSuperview()

					// print("Animation complete.\n")
			 })
			 // print("startAnimation sv, rv, pv:", String(describing: [scaleVelocity, rotationVelocity, panVelocity]))
			 animator.startAnimation()

			 self.newScale = 1.0
			 self.newRotation = 0.0
			 self.scaleVelocity = 1.0
			 self.rotationVelocity = 0.0
			 self.startPosition = self.center
			 self.panVelocity = CGPoint(x: 0, y: 0)
			 self.newTranslation = CGPoint(x: 0.0, y: 0.0)

			 return true
	  }

}

extension PreviewView: UIGestureRecognizerDelegate {
	  func gestureRecognizer(_ gr1: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith gr2: UIGestureRecognizer) -> Bool {

			 if gr1 is UITapGestureRecognizer || gr2 is UITapGestureRecognizer { return false }

			 return true

	  }
}

extension UIView {
	  func findViewController() -> UIViewController? {
			 if let nextResponder = self.next as? UIViewController {
					return nextResponder
			 } else if let nextResponder = self.next as? UIView {
					return nextResponder.findViewController()
			 } else {
					return nil
			 }
	  }
}
