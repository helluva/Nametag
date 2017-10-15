//
//  CollectionViewController.swift
//  Nametag
//
//  Created by Nate Thompson on 10/14/17.
//  Copyright © 2017 Helluva. All rights reserved.
//

import UIKit

class CollectionViewController: UIViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    
    let people = [
        (name: "Cal", image: #imageLiteral(resourceName: "cal-face")),
        (name: "Nate", image: #imageLiteral(resourceName: "nate-face"))
    ]
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBAction func swipeGestureRecognizer(_ sender: UISwipeGestureRecognizer) {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "CameraViewController") as! ViewController
        performDismissalAnimation()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        preflightPresentationAnimation()
        view.backgroundColor = .clear
    }
    
    func preflightPresentationAnimation() {
        collectionView.transform = CGAffineTransform(translationX: view.frame.width, y: 0)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        performPresentationAnimation()
    }
    
    func performPresentationAnimation() {
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            usingSpringWithDamping: 0.87,
            initialSpringVelocity: 0,
            options: [],
            animations: {
                self.collectionView.transform = .identity

        },
            completion: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        performDismissalAnimation()
    }
    
    func performDismissalAnimation() {
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            usingSpringWithDamping: 0.87,
            initialSpringVelocity: 0,
            options: [],
            animations: {
                self.collectionView.transform = CGAffineTransform(translationX: self.view.frame.width, y: 0)
        },
            completion: { _ in
                self.dismiss(animated: false, completion: nil)
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        collectionView.dataSource = self

        collectionView.contentInset = UIEdgeInsets(top: 15, left: 0, bottom: 15, right: 0)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return people.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "face", for: indexPath) as! FaceCell
        
        cell.decorate(for: people[indexPath.item].name, and: people[indexPath.item].image)
        return cell
    }
}

class FaceCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    
    func decorate(for name: String, and image: UIImage) {
        imageView.image = image
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.frame.height/2
        
        nameLabel.text = name
    }
}