import UIKit

/// Main content view controller for the AR Cue Alignment Coach
/// This is a placeholder implementation for Step 1 - basic project setup
class ContentViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up basic UI
        view.backgroundColor = .systemBackground
        setupPlaceholderUI()
    }
    
    private func setupPlaceholderUI() {
        // Create a simple label for now
        let label = UILabel()
        label.text = "AR Cue Alignment Coach\n\nStep 1: Foundation Complete\n✅ Project Structure\n✅ Core Models\n✅ Unit Tests"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .label
        
        // Add constraints
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
}