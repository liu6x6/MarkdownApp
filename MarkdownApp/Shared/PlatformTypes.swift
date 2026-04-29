import SwiftUI

#if os(macOS)
import AppKit

public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
public typealias PlatformImage = NSImage
public typealias PlatformView = NSView
public typealias PlatformViewController = NSViewController
public typealias PlatformViewRepresentable = NSViewRepresentable
public typealias PlatformViewRepresentableContext = NSViewRepresentableContext
#else
import UIKit

public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
public typealias PlatformImage = UIImage
public typealias PlatformView = UIView
public typealias PlatformViewController = UIViewController
public typealias PlatformViewRepresentable = UIViewRepresentable
public typealias PlatformViewRepresentableContext = UIViewRepresentableContext

extension UIColor {
    var controlBackgroundColor: UIColor {
        return .systemBackground
    }
}
#endif