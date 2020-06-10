
import UIKit
import CoreML
import Vision
import ImageIO

extension Sequence {
    func splitBefore(
        separator isSeparator: (Iterator.Element) throws -> Bool
    ) rethrows -> [AnySequence<Iterator.Element>] {
        var result: [AnySequence<Iterator.Element>] = []
        var subSequence: [Iterator.Element] = []

        var iterator = self.makeIterator()
        while let element = iterator.next() {
            if try isSeparator(element) {
                if !subSequence.isEmpty {
                    result.append(AnySequence(subSequence))
                }
                subSequence = [element]
            }
            else {
                subSequence.append(element)
            }
        }
        result.append(AnySequence(subSequence))
        return result
    }
}

extension Character {
    var isUpperCase: Bool { return String(self) == String(self).uppercased() }
}

class ViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var displayView: UIImageView!
    @IBOutlet weak var classificationLabel: UILabel!
    
    private var wikiButton: UIButton! = UIButton(type: UIButton.ButtonType.custom)
    
    private var classificationResult: String!
    private var queryString: String!
    private var summaryTitle: String = ""
    private var wikiImage: UIImage = UIImage.init(named: "wiki.png")!
    
    public var position_x: Double = 0.0
    public var position_y: Double = 0.0
    
    func refreshSummary() {
        let request = URLRequest(url: NSURL(string: "https://en.wikipedia.org/w/api.php?format=json&action=query&prop=extracts&exintro&explaintext&redirects=1&titles=" + self.queryString)! as URL)
        do {

            print("Request performed")

            // Perform the request
            var response: AutoreleasingUnsafeMutablePointer<URLResponse?>? = nil
            let data = try NSURLConnection.sendSynchronousRequest(request, returning: response)

            // Convert the data to JSON
            let jsonSerialized = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
            //print(jsonSerialized)
            if let json = jsonSerialized, let query = json["query"] as? NSDictionary{
                let page = query["pages"] as? NSDictionary
                var content = NSDictionary()
                for (key, value) in page! {
                    content = value as! NSDictionary
                }
                summaryTitle = content["title"] as! String
                let extract = content["extract"]
                self.summary = extract as? String
            }
        }
        catch let error as NSError
        {
            print(error.localizedDescription)
        }
    }
    
    private lazy var summary: String! = {
        let request = URLRequest(url: NSURL(string: "https://en.wikipedia.org/w/api.php?format=json&action=query&prop=extracts&exintro&explaintext&redirects=1&titles=" + self.queryString)! as URL)
        do {

            print("Request performed")

            // Perform the request
            var response: AutoreleasingUnsafeMutablePointer<URLResponse?>? = nil
            let data = try NSURLConnection.sendSynchronousRequest(request, returning: response)

            // Convert the data to JSON
            let jsonSerialized = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
            //print(jsonSerialized)
            if let json = jsonSerialized, let query = json["query"] as? NSDictionary{
                let page = query["pages"] as? NSDictionary
                var content = NSDictionary()
                for (key, value) in page! {
                    content = value as! NSDictionary
                }
                summaryTitle = content["title"] as! String
                let extract = content["extract"]
                return (extract as! String)
            }
        }
        catch let error as NSError
        {
            print(error.localizedDescription)
        }
        return ""
    }()
    
    private lazy var module: TorchModule = {
        if let filePath = Bundle.main.path(forResource: "scriptmodule_withMask", ofType: "pt"),
            let module = TorchModule(fileAtPath: filePath) {
            return module
        } else {
            fatalError("Can't find the model file!")
        }
    }()

    private lazy var labels: [String] = {
        if let filePath = Bundle.main.path(forResource: "GSV_sites", ofType: "txt"),
            let labels = try? String(contentsOfFile: filePath) {
            return labels.components(separatedBy: .newlines)
        } else {
            fatalError("Can't find the text file!")
        }
    }()
    
    var sourceImg: UIImage! {
        didSet {
            displayView.image = sourceImg
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sourceImg = UIImage.init(named: "arch.jpg")!
        refreshButton()
        wikiButton.isHidden = true
        classificationLabel.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
 
    @IBAction func handlePickerTap(_ sender: Any) {
        let imagePicker =  UIImagePickerController()
        imagePicker.delegate = self
        present(imagePicker, animated: true, completion: nil)
    }
    
    @IBAction func handleSegmentTap(_ sender: Any) {
        if let (cgImg, x, y) = sourceImg.segmentation(){
            displayView.image = UIImage(cgImage: cgImg!)
        }
    }
    
    @IBAction func handelGrayTap(_ sender: Any) {
        if let (cgImg, x, y) = sourceImg.segmentation(){
            let filter = GraySegmentFilter()
            self.position_x = x
            self.position_y = y
            filter.inputImage = CIImage.init(cgImage: sourceImg.cgImage!)
            filter.maskImage = CIImage.init(cgImage: cgImg!)
            let output = filter.value(forKey:kCIOutputImageKey) as! CIImage
            
            let ciContext = CIContext(options: nil)
            let cgImage = ciContext.createCGImage(output, from: output.extent)!
            //displayView.image = UIImage(cgImage: cgImage)
            
            let resizedImage = UIImage(cgImage: cgImage).resized(to: CGSize(width: 224, height: 224))
            guard var pixelBuffer = resizedImage.normalized() else {
                return
            }
            guard let outputs = module.predict(image: UnsafeMutableRawPointer(&pixelBuffer)) else {
                return
            }
            let zippedResults = zip(labels.indices, outputs)
            let sortedResults = zippedResults.sorted { $0.1.floatValue > $1.1.floatValue }.prefix(3)
            var text = ""
            for result in sortedResults {
                text += "\u{2022} \(labels[result.0]) \n\n"
            }
            self.classificationResult = labels[sortedResults[0].0].components(separatedBy: ",")[0]
            self.classificationLabel.text = text
            
            let splitted = self.classificationResult
                .characters
                .splitBefore(separator: { $0.isUpperCase })
                .map{String($0)}
            var queryString = ""
            for splitWord in splitted{
                queryString += splitWord + "%20"
            }
            self.queryString = String(queryString.dropLast().dropLast().dropLast())
            
            if queryString != "Null%20Class%20"{
                self.wikiButton.isHidden = false
                refreshButton()
            }
            self.refreshSummary()
            //updateClassifications(for: displayView.image!)
        }
    }
    
    func refreshButton() {
        let buttonX = Int(300 * self.position_x)//150
        let buttonY = Int(800 * self.position_y)//400
        let buttonWidth = 100
        let buttonHeight = 100

        wikiButton.frame = CGRect(x: buttonX, y: buttonY, width: buttonWidth, height: buttonHeight)
        wikiButton.setTitle("Click here", for: .normal)
        wikiButton.setImage(wikiImage, for: .normal)
        //button.tintColor = .white
        //button.backgroundColor = .red
        wikiButton.addTarget(self, action: #selector(buttonClicked), for: .touchUpInside)


        self.view.addSubview(wikiButton)
    }
    
    
    @objc func buttonClicked(sender : UIButton){
        let alert = AlertController(title: summaryTitle, message: summary, preferredStyle: .alert)
        //alert.setTitleImage(displayView.image)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { action in
            switch action.style{
            case .default:
                print("default")

            case .cancel:
                print("cancel")

            case .destructive:
                print("destructive")
            }
        }))
        self.present(alert, animated: true, completion: nil)
       }
    
/// Adds ability to display `UIImage` above the title label of `UIAlertController`.
/// Functionality is achieved by adding “\n” characters to `title`, to make space
/// for `UIImageView` to be added to `UIAlertController.view`. Set `title` as
/// normal but when retrieving value use `originalTitle` property.
class AlertController: UIAlertController {
    /// - Return: value that was set on `title`
    private(set) var originalTitle: String?
    private var spaceAdjustedTitle: String = ""
    private weak var imageView: UIImageView? = nil
    private var previousImgViewSize: CGSize = .zero
    
    override var title: String? {
        didSet {
            // Keep track of original title
            if title != spaceAdjustedTitle {
                originalTitle = title
            }
        }
    }
    
    /// - parameter image: `UIImage` to be displayed about title label
    func setTitleImage(_ image: UIImage?) {
        guard let imageView = self.imageView else {
            let imageView = UIImageView(image: image)
            self.view.addSubview(imageView)
            self.imageView = imageView
            return
        }
        imageView.image = image
    }
    
    // MARK: -  Layout code
    
    override func viewDidLayoutSubviews() {
        guard let imageView = imageView else {
            super.viewDidLayoutSubviews()
            return
        }
        // Adjust title if image size has changed
        if previousImgViewSize != imageView.bounds.size {
            previousImgViewSize = imageView.bounds.size
            adjustTitle(for: imageView)
        }
        // Position `imageView`
        let linesCount = newLinesCount(for: imageView)
        let padding = Constants.padding(for: preferredStyle)
        imageView.center.x = view.bounds.width / 2.0
        imageView.center.y = padding + linesCount * lineHeight / 2.0
        super.viewDidLayoutSubviews()
    }
    
    /// Adds appropriate number of "\n" to `title` text to make space for `imageView`
    private func adjustTitle(for imageView: UIImageView) {
        let linesCount = Int(newLinesCount(for: imageView))
        let lines = (0..<linesCount).map({ _ in "\n" }).reduce("", +)
        spaceAdjustedTitle = lines + (originalTitle ?? "")
        title = spaceAdjustedTitle
    }
    
    /// - Return: Number new line chars needed to make enough space for `imageView`
    private func newLinesCount(for imageView: UIImageView) -> CGFloat {
        return ceil(imageView.bounds.height / lineHeight)
    }
    
    /// Calculated based on system font line height
    private lazy var lineHeight: CGFloat = {
        let style: UIFont.TextStyle = self.preferredStyle == .alert ? .headline : .callout
        return UIFont.preferredFont(forTextStyle: style).pointSize
    }()
    
    struct Constants {
        static var paddingAlert: CGFloat = 22
        static var paddingSheet: CGFloat = 11
        static func padding(for style: UIAlertController.Style) -> CGFloat {
            return style == .alert ? Constants.paddingAlert : Constants.paddingSheet
        }
    }
}
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
}

extension ViewController: UIImagePickerControllerDelegate,UINavigationControllerDelegate {
 
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let pickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            sourceImg = pickedImage.resize(size: CGSize(width: 1200, height: 1200 * (pickedImage.size.height / pickedImage.size.width)))
        }
 
        picker.dismiss(animated: true, completion: nil)
        wikiButton.isHidden = true
    }
    
}
