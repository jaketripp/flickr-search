//
//  FlickrPhotosViewController.swift
//  FlickrSearch
//
//  Created by Tripp,Jacob on 9/27/18.
//  Copyright © 2018 Tripp,Jacob. All rights reserved.
//

import UIKit
final class FlickrPhotosViewController: UICollectionViewController {
    
    // MARK: - Properties
    fileprivate let reuseIdentifier = "FlickrCell"
    fileprivate let sectionInsets = UIEdgeInsets(top: 20.0, left: 20.0, bottom: 20.0, right: 20.0)
    fileprivate var searches = [FlickrSearchResults]()
    fileprivate let flickr = Flickr()
    fileprivate let itemsPerRow: CGFloat = 3
    fileprivate var selectedPhotos = [FlickrPhoto]()
    fileprivate let shareTextLabel = UILabel()
    
    //1
    var largePhotoIndexPath: NSIndexPath? {
        didSet {
            //2
            var indexPaths = [IndexPath]()
            if let largePhotoIndexPath = largePhotoIndexPath {
                indexPaths.append(largePhotoIndexPath as IndexPath)
            }
            if let oldValue = oldValue {
                indexPaths.append(oldValue as IndexPath)
            }
            //3
            collectionView?.performBatchUpdates({
                self.collectionView?.reloadItems(at: indexPaths)
            }) { completed in
                //4
                if let largePhotoIndexPath = self.largePhotoIndexPath {
                    self.collectionView?.scrollToItem(
                        at: largePhotoIndexPath as IndexPath,
                        at: .centeredVertically,
                        animated: true)
                }
            }
        }
    }
    var sharing: Bool = false {
        didSet {
            collectionView?.allowsMultipleSelection = sharing
            collectionView?.selectItem(at: nil, animated: true, scrollPosition: UICollectionViewScrollPosition())
            selectedPhotos.removeAll(keepingCapacity: false)
            
            guard let shareButton = self.navigationItem.rightBarButtonItems?.first else {
                return
            }
            
            guard sharing else {
                navigationItem.setRightBarButtonItems([shareButton], animated: true)
                return
            }
            
            if let _ = largePhotoIndexPath  {
                largePhotoIndexPath = nil
            }
            
            updateSharedPhotoCount()
            let sharingDetailItem = UIBarButtonItem(customView: shareTextLabel)
            navigationItem.setRightBarButtonItems([shareButton,sharingDetailItem], animated: true)
        }
    }
    
    @IBAction func share(_ sender: UIBarButtonItem) {
        guard !searches.isEmpty else {
            return
        }
        
        guard !selectedPhotos.isEmpty else {
            sharing = !sharing
            return
        }
        
        guard sharing else  {
            return
        }
        
        var imageArray = [UIImage]()
        for selectedPhoto in selectedPhotos {
            if let thumbnail = selectedPhoto.thumbnail {
                imageArray.append(thumbnail)
            }
        }
        
        if !imageArray.isEmpty {
            let shareScreen = UIActivityViewController(activityItems: imageArray, applicationActivities: nil)
            shareScreen.completionWithItemsHandler = { (_, _, _, _) in
                self.sharing = false
            }
            let popoverPresentationController = shareScreen.popoverPresentationController
            popoverPresentationController?.barButtonItem = sender
            popoverPresentationController?.permittedArrowDirections = .any
            present(shareScreen, animated: true, completion: nil)
        }

    }

}

// MARK: - UICollectionViewDataSource
extension FlickrPhotosViewController {
    //1
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return searches.count
    }
    
    //2
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searches[section].searchResults.count
    }
    
    override func collectionView(_ collectionView: UICollectionView,
                                 viewForSupplementaryElementOfKind kind: String,
                                 at indexPath: IndexPath) -> UICollectionReusableView {
        //1
        switch kind {
        //2
        case UICollectionElementKindSectionHeader:
            //3
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                             withReuseIdentifier: "FlickrPhotoHeaderView",
                                                                             for: indexPath) as! FlickrPhotoHeaderView
            headerView.label.text = searches[(indexPath as NSIndexPath).section].searchTerm
            return headerView
        default:
            //4
            assert(false, "Unexpected element kind")
        }
    }

    
    //3
    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: reuseIdentifier, for: indexPath as IndexPath) as! FlickrPhotoCell
        var flickrPhoto = photoForIndexPath(indexPath: indexPath)
        
        //1
        cell.activityIndicator.stopAnimating()
        
        // largePhotoIndexPath! as IndexPath == indexPath
        //2
        guard indexPath as NSIndexPath == largePhotoIndexPath else {
            cell.imageView.image = flickrPhoto.thumbnail
            return cell
        }
        
        //3
        guard flickrPhoto.largeImage == nil else {
            cell.imageView.image = flickrPhoto.largeImage
            return cell
        }
        
        //4
        cell.imageView.image = flickrPhoto.thumbnail
        cell.activityIndicator.startAnimating()
        
        //5
        flickrPhoto.loadLargeImage { loadedFlickrPhoto, error in
            
            //6
            cell.activityIndicator.stopAnimating()
            
            //7
            guard loadedFlickrPhoto.largeImage != nil && error == nil else {
                return
            }
            
            //8
            if let cell = collectionView.cellForItem(at: indexPath) as? FlickrPhotoCell, indexPath == self.largePhotoIndexPath! as IndexPath {
                cell.imageView.image = loadedFlickrPhoto.largeImage
            }
        }
        
        return cell
    }



}

extension FlickrPhotosViewController : UICollectionViewDelegateFlowLayout {
    //1
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        // New code
        if indexPath as NSIndexPath == largePhotoIndexPath {
            let flickrPhoto = photoForIndexPath(indexPath: indexPath)
            var size = collectionView.bounds.size
            size.height -= view.safeAreaInsets.top
            size.height -= (sectionInsets.top + sectionInsets.right)
            size.width -= (sectionInsets.left + sectionInsets.right)
            return flickrPhoto.sizeToFillWidthOfSize(size)
        }
        
        //2
        let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
        let availableWidth = view.frame.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow
        
        return CGSize(width: widthPerItem, height: widthPerItem)
    }
    
    //3
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return sectionInsets
    }
    
    // 4
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return sectionInsets.left
    }
}


extension FlickrPhotosViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // 1
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        textField.addSubview(activityIndicator)
        activityIndicator.frame = textField.bounds
        activityIndicator.startAnimating()
        
        flickr.searchFlickrForTerm(textField.text!) {
            results, error in
            
            
            activityIndicator.removeFromSuperview()
            
            
            if let error = error {
                // 2
                print("Error searching : \(error)")
                return
            }
            
            if let results = results {
                // 3
                print("Found \(results.searchResults.count) matching \(results.searchTerm)")
                self.searches.insert(results, at: 0)
                
                // 4
                self.collectionView?.reloadData()
            }
        }
        
        textField.text = nil
        textField.resignFirstResponder()
        return true
    }
    override func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        
        var sourceResults = searches[(sourceIndexPath as NSIndexPath).section].searchResults
        let flickrPhoto = sourceResults.remove(at: (sourceIndexPath as NSIndexPath).row)
        searches[(sourceIndexPath as NSIndexPath).section].searchResults = sourceResults

        var destinationResults = searches[(destinationIndexPath as NSIndexPath).section].searchResults
        destinationResults.insert(flickrPhoto, at: (destinationIndexPath as NSIndexPath).row)
        searches[(destinationIndexPath as NSIndexPath).section].searchResults = destinationResults
        
    }

}

// MARK: - UICollectionViewDelegate
extension FlickrPhotosViewController {
    
    override func collectionView(_ collectionView: UICollectionView,
                                 shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard !sharing else {
            return true
        }

        largePhotoIndexPath = largePhotoIndexPath == indexPath as NSIndexPath ? nil : indexPath as NSIndexPath
        return false
    }
    
    override func collectionView(_ collectionView: UICollectionView,
                                 didSelectItemAt indexPath: IndexPath) {
        guard sharing else {
            return
        }
        
        let photo = photoForIndexPath(indexPath: indexPath)
        selectedPhotos.append(photo)
        updateSharedPhotoCount()
    }
    override func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard sharing else {
            return
        }
        
        let photo = photoForIndexPath(indexPath: indexPath)
        
        if let index = selectedPhotos.index(of: photo) {
            selectedPhotos.remove(at: index)
            updateSharedPhotoCount()
        }
    }

}

// MARK: - Private
private extension FlickrPhotosViewController {
    func photoForIndexPath(indexPath: IndexPath) -> FlickrPhoto {
        return searches[(indexPath as NSIndexPath).section].searchResults[(indexPath as IndexPath).row]
    }
    
    func updateSharedPhotoCount() {
        shareTextLabel.textColor = themeColor
        shareTextLabel.text = "\(selectedPhotos.count) \(selectedPhotos.count == 1 ? "photo" : "photos") selected"
        shareTextLabel.sizeToFit()
    }

}
