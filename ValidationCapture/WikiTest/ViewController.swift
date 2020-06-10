//
//  ViewController.swift
//  IOSTakePhotoTutorial
//
//  Created by Arthur Knopper on 18/12/2018.
//  Copyright © 2018 Arthur Knopper. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate, CLLocationManagerDelegate, UITextFieldDelegate{
    let documentInteractionController = UIDocumentInteractionController()
    var imagePicker: UIImagePickerController!
    var locationManager = CLLocationManager()
    
    @IBOutlet weak var coordLabel: UITextField!
    @IBOutlet weak var dirLabel: UITextField!
    @IBOutlet weak var nameLabel: UITextField!
    
    @IBOutlet weak var imageView: UIImageView!
    @IBAction func takePhoto(_ sender: Any) {
        imagePicker =  UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        
        present(imagePicker, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        startLocation()
        coordLabel.delegate = self
        coordLabel.returnKeyType = UIReturnKeyType.done
        dirLabel.delegate = self
        dirLabel.returnKeyType = UIReturnKeyType.done
        nameLabel.delegate = self
        nameLabel.returnKeyType = UIReturnKeyType.done
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func startLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.headingOrientation = .portrait
        locationManager.headingFilter = kCLHeadingFilterNone
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        print("started location")
    }
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        imagePicker.dismiss(animated: true, completion: nil)
        imageView.image = info[.originalImage] as? UIImage
        
    }
    
    @IBAction func saveButton(_ sender: Any) {
        let saveName = nameLabel.text! + "_" + getTodayString()
        print(saveName)
        saveImageGPSDirection(name: saveName)
    }
    
    func saveImageGPSDirection(name: String) {
        if let image = self.imageView.image {
            if let data = image.jpegData(compressionQuality: 0.5) {
                let filename = getDocumentsDirectory().appendingPathComponent("\(name).png")
                try? data.write(to: filename)
            }
        }
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent("\(name).csv")
            let text = "\(name),\(coordLabel.text!),\(dirLabel.text!)"
            do {
                try text.write(to: fileURL, atomically: false, encoding: .utf8)
            }
            catch {/* error handling here */}
        }
    }
    
    func getTodayString() -> String{
             let date = Date()
             let calender = Calendar.current
             let components = calender.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date)

             let year = components.year
             let month = components.month
             let day = components.day
             let hour = components.hour
             let minute = components.minute
             let second = components.second

             let today_string = String(year!) + "-" + String(month!) + "-" + String(day!) + " " + String(hour!)  + ":" + String(minute!) + ":" +  String(second!)
             return today_string
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else { return }
        coordLabel.text = "\(round(locValue.latitude*10000)/10000),\(round(locValue.longitude*10000)/10000)"
        print("locations = \(locValue.latitude) \(locValue.longitude)")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        dirLabel.text = "\(round(newHeading.magneticHeading))"
        print("headings = \(newHeading.magneticHeading)")
    }

}
