//
//  LoopView.swift
//  FFLoopView
//
//  Created by 刘凡 on 15/11/15.
//  Copyright © 2015年 joyios. All rights reserved.
//

import UIKit
import SDWebImage

/// 提示视图位置
///
/// - None:    无
/// - Overlay: 在下方层叠显示
/// - Split:   在下方拆分显示
@objc public enum TipViewPosition: Int {
    case None
    case Overlay
    case Split
}
/// 分页视图位置
///
/// - None:   无
/// - Center: CollectionView 的中下方，即使包含 TipView 也不会显示在 TipView 中
/// - Right:  右侧
@objc public enum PagingViewPosition: Int {
    case None
    case Center
    case Right
}

/// 可重用标识符
private let LoopViewCellIdentifier = "LoopViewCellIdentifier"

/**
 图片轮播器视图
 
 * 示例代码
 
 ```
 loopView.showImages(urls, tips: tips) { [weak self] index in
    print("选中了第 \(index) 张图像 \(self?.view)")
 }
 ```
 
 * 参数
 1. urls: 轮播器图像的 URL 数组
 2. tips: 每张图片对应的提示信息字符串数组，可以为 nil
 3. 完成回调：index 选中图像的索引值
 
 * 重要
 1. 完成闭包中的 self 需要使用 `[weak self]` 否则会出现循环引用
 2. 如果需要释放轮播器视图，需要先调用 `loopView.stopTimer()` 关闭时钟，否则会出现内存泄漏
 3. 如果由于设备旋转需要重新更新轮播器布局，可以调用 `loopView.relayoutView()`
 */
public class LoopView: UIView {
    
    /// 提示视图位置
    public var tipViewPosition: TipViewPosition = .Overlay {
        didSet {
            remakeConstraints()
        }
    }
    /// 提示视图
    public lazy var tipView: UIView = UIView()
    /// 提示标签
    public lazy var tipLabel: UILabel = UILabel()
    
    /// 分页视图位置
    public var pagingViewPosition: PagingViewPosition = .Right {
        didSet {
            remakeConstraints()
        }
    }
    /// 分页视图
    public lazy var pagingView: PagingView = PagingView()
    
    // MARK: - 构造函数
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        prepareUI()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        prepareUI()
    }
    
    deinit {
        print("\(classForCoder) \(__FUNCTION__)")
    }
    
    // MARK: 公共函数
    /// 显示图像
    ///
    /// - parameter urls:          图片 URL 数组
    /// - parameter tips:          图片描述信息字符串数组，可以为 nil
    /// - parameter timeInterval:  (可选)时钟触发时长，默认 5.0
    /// - parameter selectedImage: (可选)选中图片回调，可以为 nil
    public func showImages(urls: [NSURL],
        tips: [String]?,
        timeInterval: NSTimeInterval = 5.0,
        selectedImage: ((index: Int) -> ())? = nil) {
            
            // 记录回调
            selectedImageCallBack = selectedImage
            self.timeInterval = timeInterval
            
            // 准备数据
            prepareData(urls, tips: tips)
            
            if imageUrls?.count <= 1 {
                return
            }
            
            // 滚动到倒数第二张图片
            dispatch_async(dispatch_get_main_queue()) {
                //  Prepare view for data
                self.collectionView.reloadData()
                self.collectionView.scrollToItemAtIndexPath(NSIndexPath(forItem: urls.count, inSection: 0),
                    atScrollPosition: .Left,
                    animated: false)
            }
            
            // 开启时钟
            startTimer()
    }
    
    /// 停止时钟，释放对象时，需要调用此方法
    public func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    /// 开启时钟
    public func startTimer() {
        if imageUrls?.count <= 1 || timer != nil {
            return
        }
        
        timer = NSTimer(timeInterval: timeInterval,
            target: self,
            selector: "fireTimer",
            userInfo: nil,
            repeats: true)
        NSRunLoop.currentRunLoop().addTimer(timer!, forMode: NSRunLoopCommonModes)
    }
    
    /// 重新调整视图布局
    public func relayoutView() {
        
        let indexPath = collectionView.indexPathsForVisibleItems()[0]
        
        collectionView.collectionViewLayout.invalidateLayout()
        
        dispatch_async(dispatch_get_main_queue()) {
            self.stopTimer()
            self.collectionView.scrollToItemAtIndexPath(indexPath, atScrollPosition: .Left, animated: false)
            self.startTimer()
        }
    }
    
    // MARK: 私有函数
    /// 时钟监听函数
    @objc private func fireTimer() {
        guard let indexPath = collectionView.indexPathsForVisibleItems().last else {
            return
        }
        
        let next = NSIndexPath(forItem: indexPath.item + 1, inSection: indexPath.section)
        if next.item == imageUrls?.count {
            return
        }
        
        collectionView.scrollToItemAtIndexPath(next, atScrollPosition: .Left, animated: true)
    }
    
    /// 准备数据
    ///
    /// - parameter urls: 图片 URL 数组
    /// - parameter tips: 图片描述信息字符串数组，可以为 nil
    private func prepareData(urls: [NSURL], tips: [String]?) {
        
        assert(tips == nil || tips?.count == urls.count, "tips 应该为 nil 或者数量与 urls 相等")
        
        // 记录数据
        imageUrls = urls
        imageTips = tips
        
        // 总页数
        pagingView.numberOfPages = urls.count
        
        // 处理 URL 数组
        if imageUrls?.count > 1 {
            imageUrls?.append(imageUrls![0])
            imageUrls?.append(imageUrls![1])
        }
        
        // 处理提示信息
        if imageTips?.count > 1 {
            imageTips?.append(imageTips![0])
            imageTips?.append(imageTips![1])
        }
    }
    
    // MARK: 私有属性
    /// 选中图像回调
    private var selectedImageCallBack: ((index: Int) -> ())?
    /// 图像 URL 数组
    private var imageUrls: [NSURL]?
    /// 图像描述信息
    private var imageTips: [String]?
    /// 定时器
    private var timer: NSTimer?
    /// 时钟触发时长，默认 5.0
    private var timeInterval: NSTimeInterval = 5.0
    
    /// collectionView
    private lazy var collectionView = UICollectionView(frame: CGRectZero, collectionViewLayout: LoopViewLayout())
    /// 当前布局数组
    private lazy var currentConstraints = [NSLayoutConstraint]()
    
    // MARK: - 自定义 collectionView 布局
    private class LoopViewLayout: UICollectionViewFlowLayout {
        
        private override func prepareLayout() {
            
            itemSize = collectionView!.bounds.size
            minimumInteritemSpacing = 0
            minimumLineSpacing = 0
            scrollDirection = .Horizontal
            
            collectionView?.pagingEnabled = true
            collectionView?.showsHorizontalScrollIndicator = false
            collectionView?.showsVerticalScrollIndicator = false
            collectionView?.bounces = false
            
            super.prepareLayout()
        }
    }
}

// MARK: - 设置界面
private extension LoopView {
    
    private func prepareUI() {
        
        backgroundColor = UIColor.whiteColor()
        
        prepareCollectionView()
        prepareTipView()
        preparePageView()
        
        remakeConstraints()
    }
    
    /// 重建视图布局
    private func remakeConstraints() {
        
        removeConstraints(currentConstraints)
        currentConstraints.removeAll()
        
        let views = ["collectionView": collectionView, "tipView": tipView, "pagingView": pagingView]
        var formats: [String]
        
        // 提示视图
        switch tipViewPosition {
        case .Overlay:
            formats = ["H:|-0-[collectionView]-0-|",
                "V:|-0-[collectionView]-0-|",
                "H:|-0-[tipView]-0-|",
                "V:[tipView(36)]-0-|"]
        case .Split:
            formats = ["H:|-0-[collectionView]-0-|",
                "H:|-0-[tipView]-0-|",
                "V:|-0-[collectionView]-0-[tipView(36)]-0-|"]
        default:
            formats = ["H:|-0-[collectionView]-0-|",
                "V:|-0-[collectionView]-0-|"]
        }
        tipView.hidden = (tipViewPosition == .None)
        
        // 分页视图
        switch pagingViewPosition {
        case .Center:
            formats += ["H:[pagingView(36)]", "V:[pagingView(36)]"]
            currentConstraints.append(NSLayoutConstraint(item: pagingView,
                attribute: .CenterX,
                relatedBy: .Equal,
                toItem: collectionView,
                attribute: .CenterX,
                multiplier: 1.0,
                constant: 0))
            currentConstraints.append(NSLayoutConstraint(item: pagingView,
                attribute: .Bottom,
                relatedBy: .Equal,
                toItem: collectionView,
                attribute: .Bottom,
                multiplier: 1.0,
                constant: 0))
        case .Right:
            formats += ["H:[pagingView(36)]-0-|", "V:[pagingView(36)]-0-|"]
        default: break;
        }
        pagingView.hidden = (pagingViewPosition == .None)
        
        // 安装约束
        disableSubviewsAutoresizing()
        currentConstraints += NSLayoutConstraint.constraints(formats, views: views)
        addConstraints(currentConstraints)
    }
    
    /// 准备分页视图
    private func preparePageView() {
        
        addSubview(pagingView)
        
        pagingView.userInteractionEnabled = false
        pagingView.numberOfPages = 0
        pagingView.currentPage = 0
        pagingView.hidesForSinglePage = true

        pagingView.pageIndicatorTintColor = UIColor.whiteColor()
        pagingView.currentPageIndicatorTintColor = UIColor.redColor()
        
        pagingView.backgroundColor = UIColor.clearColor()
    }
    
    /// 准备提示视图
    private func prepareTipView() {
        
        addSubview(tipView)
        
        tipView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        tipView.userInteractionEnabled = false
        
        tipView.addSubview(tipLabel)
        tipLabel.font = UIFont.systemFontOfSize(14)
        tipLabel.textColor = UIColor.whiteColor()
        
        tipView.disableSubviewsAutoresizing()
        let formats = ["H:|-8-[tipLabel]", "V:|-0-[tipLabel]-0-|"]
        
        tipView.addConstraints(NSLayoutConstraint.constraints(formats, views: ["tipLabel": tipLabel]))
    }
    
    private func prepareCollectionView() {
        collectionView.backgroundColor = UIColor.whiteColor()
        
        addSubview(collectionView)
        
        collectionView.registerClass(LoopViewCell.self, forCellWithReuseIdentifier: LoopViewCellIdentifier)
        
        collectionView.dataSource = self
        collectionView.delegate = self
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate
extension LoopView: UICollectionViewDataSource, UICollectionViewDelegate {
    
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageUrls?.count ?? 0
    }
    
    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(LoopViewCellIdentifier, forIndexPath: indexPath) as! LoopViewCell
        
        cell.imageURL = imageUrls![indexPath.item]
        tipLabel.text = imageTips?[indexPath.item]
        
        return cell
    }
    
    public func collectionView(collectionView: UICollectionView, didEndDisplayingCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        
        guard var offset = collectionView.indexPathsForVisibleItems().last?.item else {
            return
        }
        guard let imageUrls = imageUrls else {
            return
        }
        
        if offset == imageUrls.count - 1 || offset == 0 {
            offset = (offset == 0) ? (imageUrls.count - 2) : 1
            
            collectionView.scrollToItemAtIndexPath(NSIndexPath(forItem: offset, inSection: 0),
                atScrollPosition: .Left,
                animated: false)
        }
        
        tipLabel.text = imageTips?[offset]
        pagingView.currentPage = offset % pagingView.numberOfPages
    }
    
    public func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        startTimer()
    }
    
    public func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        stopTimer()
    }
    
    public func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        let count = imageUrls?.count > 1 ? imageUrls!.count - 2 : 1
        
        selectedImageCallBack?(index: indexPath.item % count)
    }
}

// MARK: - class LoopViewCell
private class LoopViewCell: UICollectionViewCell {
    
    var imageURL: NSURL? {
        didSet {
            guard let imageURL = imageURL else {
                return
            }
            
            imageView?.sd_setImageWithURL(imageURL,
                placeholderImage: nil,
                options: [.RefreshCached, .RetryFailed])
        }
    }
    
    // MARK: 构造函数
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        prepareUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: 设置界面
    private func prepareUI() {
        imageView = UIImageView()
        contentView.addSubview(imageView!)
        
        let views = ["imageView": imageView!]
        let formats = ["H:|-0-[imageView]-0-|", "V:|-0-[imageView]-0-|"]
        
        contentView.disableSubviewsAutoresizing()
        contentView.addConstraints(NSLayoutConstraint.constraints(formats, views: views))
        
        imageView?.backgroundColor = UIColor.whiteColor()
    }
    
    // MARK: 私有属性
    private var imageView: UIImageView?
}
