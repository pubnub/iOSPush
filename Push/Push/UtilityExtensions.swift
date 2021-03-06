//
//  UtilityExtensions.swift
//  Push
//
//  Created by Jordan Zucker on 1/9/17.
//  Copyright © 2017 PubNub. All rights reserved.
//

import Foundation
import UIKit
import CoreData

// http://stackoverflow.com/questions/26542035/create-uiimage-with-solid-color-in-swift
public extension UIImage {
    public convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
}

extension UIView {
    
    static func reuseIdentifier() -> String {
        return NSStringFromClass(self)
    }
}

extension UIView {
    
    var hasConstraints: Bool {
        let hasHorizontalConstraints = !self.constraintsAffectingLayout(for: .horizontal).isEmpty
        let hasVerticalConstraints = !self.constraintsAffectingLayout(for: .vertical).isEmpty
        return hasHorizontalConstraints || hasVerticalConstraints
    }
    
    func forceAutoLayout() {
        self.translatesAutoresizingMaskIntoConstraints = false
    }
}

extension UINavigationItem {
    func setPrompt(with message: String, for duration: Double = 3.0) {
        assert(duration > 0.0)
        assert(duration < 10.0)
        self.prompt = message
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.prompt = nil
        }
    }
    
}
