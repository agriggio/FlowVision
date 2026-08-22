//
//  CustomImageView.swift
//  FlowVision
//

import Foundation
import Cocoa

class CustomImageView: NSImageView {
    
    var isFolder = false
    var url: URL? = nil

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let viewController = getViewController(self){
            if viewController.publicVar.isInLargeView {
                return .link
            }else if isFolder{
                return .copy
            }
        }
        return .every
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer {
            sender.draggingPasteboard.clearContents()
        }
        
        if let viewController = getViewController(self){
            if viewController.publicVar.isInLargeView {
                let pasteboard = sender.draggingPasteboard
                if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
                    viewController.handleDraggedFiles(urls)
                    return true
                }
            }else if isFolder{
                viewController.handleMove(targetURL: url, pasteboard: sender.draggingPasteboard)
                return true
            }else{
                if sender.draggingSource is CustomCollectionView {
                    return false
                }
                if let curFolderUrl = URL(string: viewController.fileDB.curFolder){
                    let pasteboard = sender.draggingPasteboard
                    if viewController.handleFilePromiseDrop(targetURL: curFolderUrl, pasteboard: pasteboard) {
                        return true
                    }
                    viewController.handleMove(targetURL: curFolderUrl, pasteboard: pasteboard)
                    return true
                }
            }
        }
        return false
    }
    
    var center: CGPoint {
        get {
            return CGPoint(x: frame.midX, y: frame.midY)
        }
        set(newCenter) {
            var newFrame = frame
            newFrame.origin.x = newCenter.x - (newFrame.size.width / 2)
            newFrame.origin.y = newCenter.y - (newFrame.size.height / 2)
            frame = newFrame
        }
    }
}

class BorderedImageView: IntegerImageView {
    
    var isDrawBorder=false
    
    // 发现会导致加载速度变慢，因此暂时不使用
    // Found to cause slower loading speed, so temporarily not used
//    override func draw(_ dirtyRect: NSRect) {
//        super.draw(dirtyRect)
//        
//        if isDrawBorder {
//            drawBorder(dirtyRect)
//        }
//    }
    
    func drawBorder(_ dirtyRect: NSRect) {
        // 确保图像存在
        // Ensure image exists
        guard let image = self.image else {
            return
        }
        
        // 设置边框颜色和宽度
        // Set border color and width
        let borderColor = NSColor.gray
        let borderWidth: CGFloat = 2.0
        
        // 计算图像在视图中的绘制区域，考虑边框宽度
        // Calculate image drawing area in view, considering border width
        let imageSize = image.size
        let viewSize = self.bounds.size
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        var drawRect = NSRect.zero
        
        if imageAspect > viewAspect {
            drawRect.size.width = viewSize.width - 2 * borderWidth
            drawRect.size.height = drawRect.size.width / imageAspect
            drawRect.origin.y = (viewSize.height - drawRect.size.height) / 2
            drawRect.origin.x = borderWidth
        } else {
            drawRect.size.height = viewSize.height - 2 * borderWidth
            drawRect.size.width = drawRect.size.height * imageAspect
            drawRect.origin.x = (viewSize.width - drawRect.size.width) / 2
            drawRect.origin.y = borderWidth
        }
        
        // 平移绘制区域以确保边框不会被裁剪
        // Translate drawing area to ensure border won't be clipped
        drawRect = drawRect.insetBy(dx: -borderWidth / 2, dy: -borderWidth / 2)
        
        // 绘制图像
        // Draw image
        // image.draw(in: drawRect)
        
        // 绘制边框
        // Draw border
        borderColor.set()
        let borderPath = NSBezierPath(rect: drawRect)
        borderPath.lineWidth = borderWidth
        borderPath.stroke()
    }

}

class InterpolatedImageView: CustomImageView {
    // 对于小图此方法可以提高质量
    // For small images this method can improve quality
    // 但只要override，即使不设置插值方法，也会导致巨大图像例如清明上河图100%显示时不够清晰，奇怪
    // But just by overriding, even without setting interpolation method, it causes large images like "Along the River During the Qingming Festival" to be unclear at 100% display, strange
    // 因此暂时不使用
    // So temporarily not used
//    override func draw(_ dirtyRect: NSRect) {
//        NSGraphicsContext.current!.imageInterpolation = NSImageInterpolation.high
//        super.draw(dirtyRect)
//    }
}

class IntegerImageView: CustomImageView {
    // Use floating-point numbers to store the precise position and size
    private var internalOrigin: CGPoint = .zero
    private var internalSize: CGSize = .zero
    
    func getIntFrame () -> NSRect {
        return super.frame
    }

    // Override frame property
    override var frame: NSRect {
        get {
            // Return the frame with precise origin and size
            return NSRect(origin: internalOrigin, size: internalSize)
        }
        set {
            // Update internal floating-point origin and size
            internalOrigin = newValue.origin
            internalSize = newValue.size
            
            // Calculate rounded origin and size
            let newRoundedOrigin = CGPoint(x: round(newValue.origin.x), y: round(newValue.origin.y))
            let newRoundedSize = CGSize(width: round(newValue.size.width), height: round(newValue.size.height))
            
            // Only update the frame if it actually needs to change
            if super.frame.origin != newRoundedOrigin || super.frame.size != newRoundedSize {
                super.frame = NSRect(origin: newRoundedOrigin, size: newRoundedSize)
            }
        }
    }
}

class CustomThumbImageView: BorderedImageView {
    
}

class CustomLargeImageView: IntegerImageView {
    var isMirroredH: Bool = false
    
    override var image: NSImage? {
        get { return super.image }
        set {
            if isMirroredH, let img = newValue {
                super.image = img.flippedHorizontally()
            } else {
                super.image = newValue
            }
            updateMagnificationFilter()
        }
    }
    
    // 尺寸变化后重新判断是否为整数倍缩放
    // Re-evaluate integer-multiple zoom after the size changes
    override var frame: NSRect {
        get { return super.frame }
        set {
            super.frame = newValue
            updateMagnificationFilter()
        }
    }
    
    // 兜底：AppKit 有时直接调用 setFrameSize: 而不经过 frame 属性
    // Safety net: AppKit sometimes calls setFrameSize: without going through the frame property
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateMagnificationFilter()
    }
    
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateMagnificationFilter()
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateMagnificationFilter()
    }
    
    // 整数倍(>=1)放大时使用最近邻，即纯像素复制；其余情况保持平滑插值
    // Use nearest neighbour (pure pixel duplication) at integer magnification (>=1),
    // keep smooth interpolation in all other cases
    func updateMagnificationFilter() {
        guard let layer = self.layer else { return }
        let desired: CALayerContentsFilter = shouldUseNearestMagnification() ? .nearest : .linear
        if layer.magnificationFilter != desired {
            layer.magnificationFilter = desired
        }
        // 防御：万一图像内容位于子层
        // Defensive: in case the image content lives in a sublayer
        layer.sublayers?.forEach {
            if $0.magnificationFilter != desired { $0.magnificationFilter = desired }
        }
    }
    
    private func shouldUseNearestMagnification() -> Bool {
        guard let image = self.image else { return false }
        
        // 当前实际位图的像素尺寸；矢量表示(SVG/PDF)返回0，直接放弃
        // Pixel size of the bitmap actually installed; vector reps (SVG/PDF) report 0, so bail out
        var pixelsWide = 0
        var pixelsHigh = 0
        for rep in image.representations where rep.pixelsWide > pixelsWide {
            pixelsWide = rep.pixelsWide
            pixelsHigh = rep.pixelsHigh
        }
        guard pixelsWide > 0 && pixelsHigh > 0 else { return false }
        
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        // 使用bounds而非frame：frame的getter返回未取整的内部值，bounds才是真正渲染的尺寸
        // Use bounds rather than frame: the frame getter returns the un-rounded internal value,
        // while bounds is the size that actually gets rendered
        let deviceWidth = bounds.width * scale
        let deviceHeight = bounds.height * scale
        
        // 每个源像素占多少设备像素
        // How many device pixels each source pixel covers
        let k = (deviceWidth / CGFloat(pixelsWide)).rounded()
        guard k >= 1 else { return false }
        
        // 容差：取整到点最多引入约1个设备像素的误差
        // Tolerance: rounding the frame to whole points introduces at most ~1 device pixel of error
        let toleranceW = max(1.0, deviceWidth * 0.0005)
        let toleranceH = max(1.0, deviceHeight * 0.0005)
        return abs(deviceWidth - k * CGFloat(pixelsWide)) <= toleranceW
            && abs(deviceHeight - k * CGFloat(pixelsHigh)) <= toleranceH
    }
    
    // 对当前显示的图像执行翻转（翻转的翻转=还原，无需保存原图）
    // Flip the currently displayed image (flip of flip = restore, no need to save original)
    func updateMirror() {
        if let img = super.image {
            super.image = img.flippedHorizontally()
            updateMagnificationFilter()
        }
    }
}
