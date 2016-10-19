import UIKit
import Turbolinks
import Router

class WebViewController: VisitableViewController {
    private(set) var currentPath = ""
    private lazy var router = Router()
    private var pageTitle = ""
    
    private var topicID: Int?;
    private var topicFavoriteButton: UIBarButtonItem?
    private var topicFollowButton: UIBarButtonItem?
    private var topicLikeButton: UIBarButtonItem?
    
    convenience init(path: String) {
        self.init()
        self.visitableURL = urlWithPath(path)
        self.currentPath = path
        self.initRouter()
        self.addObserver()
    }
    
    private func urlWithPath(path: String) -> NSURL {
        var urlString = ROOT_URL + path
        if let accessToken = OAuth2.shared.accessToken {
            urlString += "?access_token=" + accessToken
        }
        
        return NSURL(string: urlString)!
    }
    
    private func initRouter() {
        self.navigationItem.rightBarButtonItem = nil
        router.bind("/topics") { [weak self] (req) in
            self?.pageTitle = "title topics".localized
        }
        router.bind("/topics/last") { [weak self] (req) in
            self?.pageTitle = "title last topics".localized
        }
        router.bind("/topics/popular") { [weak self] (req) in
            self?.pageTitle = "title popular topics".localized
        }
        router.bind("/jobs") { [weak self] (req) in
            self?.pageTitle = "title jobs".localized
        }
        router.bind("/account/edit") { [weak self] (req) in
            self?.pageTitle = "title edit account".localized
        }
        router.bind("/notifications") { [weak self] (req) in
            self?.pageTitle = "title notifications".localized
        }
        router.bind("/notes") { [weak self] (req) in
            self?.pageTitle = "title notes".localized
        }
        router.bind("/notes/:id") { [weak self] (req) in
            self?.pageTitle = "title note details".localized
        }
        router.bind("/topics/favorites") { [weak self] (req) in
            self?.pageTitle = "title favorites".localized
        }
        router.bind("/topics/new") { [weak self] (req) in
            self?.pageTitle = "title new topic".localized
        }
        router.bind("/topics/:id") { [weak self] (req) in
            if let `self` = self, idString = req.param("id"), id = Int(idString) {
                self.topicID = id
                self.addMoreButton()
                self.addTopicActionButton()
                self.loadTopicActionButtonStatus()
            }
        }
        router.bind("/topics/:id/edit") { [weak self] (req) in
            self?.pageTitle = "title edit topic".localized
        }
        router.bind("/topics/:topic_id/replies/:id/edit") { [weak self] (req) in
            self?.pageTitle = "title edit reply".localized
        }
        
        router.bind("/wiki") { [weak self] (req) in
            self?.pageTitle = "title wiki".localized
        }
        
        router.bind("/wiki/:id") { [weak self] (req) in
            self?.pageTitle = "title wiki details".localized
            self?.addMoreButton()
        }
    }
    
    private func addMoreButton() {
        var rightBarButtonItems = self.navigationItem.rightBarButtonItems ?? [UIBarButtonItem]()
        let menuButton = UIBarButtonItem(image: UIImage(named: "dropdown"), style: .Plain, target: self, action: #selector(self.showTopicContextMenu))
        rightBarButtonItems.append(menuButton)
        self.navigationItem.rightBarButtonItems = rightBarButtonItems
    }
    
    private func addObserver() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(reloadByLoginStatusChanged), name: NOTICE_SIGNIN_SUCCESS, object: nil)
        NSNotificationCenter.defaultCenter().addObserverForName(NOTICE_SIGNOUT, object: nil, queue: nil) { [weak self] (notification) in
            guard let `self` = self else {
                return
            }
            let js = "document.cookie = '_homeland_session=; Path=/; Expires=Thu, 01 Jan 1970 00:00:01 GMT;';";
            self.visitableView.webView?.evaluateJavaScript(js, completionHandler: nil)
            self.reloadByLoginStatusChanged()
        }
    }
    
    func reloadByLoginStatusChanged() {
        visitableURL = urlWithPath(currentPath)
        if isViewLoaded() {
            reloadVisitable()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        TurbolinksSessionLib.sharedInstance.visit(self)
        router.match(NSURL(string: self.currentPath)!)
        navigationItem.title = pageTitle
    }
    
    override func visitableDidRender() {
        // 覆盖 visitableDidRender，避免设置 title
        navigationItem.title = pageTitle
    }
    
    func showTopicContextMenu() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        let shareAction = UIAlertAction(title: "share".localized, style: .Default, handler: { [weak self] action in
            guard let `self` = self,
                webView = self.visitableView.webView,
                title = webView.title,
                url = webView.URL,
                components = NSURLComponents(URL: url, resolvingAgainstBaseURL: false) else {
                return
            }
            components.query = nil
            components.fragment = nil
            self.share(title, url: components.URL!)
        })
        sheet.addAction(shareAction)
        let moveToFooterAction = UIAlertAction(title: "move to footer".localized, style: .Default, handler: { [weak self] action in
            guard let `self` = self, scrollView = self.visitableView.webView?.scrollView else {
                return
            }
            let offset = CGPoint(x: 0, y: scrollView.contentSize.height - scrollView.frame.height)
            if offset.y < 0 {
                return
            }
            scrollView.setContentOffset(offset, animated: true)
        })
        sheet.addAction(moveToFooterAction)
        
        let cancelAction = UIAlertAction(title: "cancel".localized, style: .Cancel, handler: nil)
        sheet.addAction(cancelAction)
        self.presentViewController(sheet, animated: true, completion: nil)
    }
    
    lazy var errorView: ErrorView = {
        let view = NSBundle.mainBundle().loadNibNamed("ErrorView", owner: self, options: nil)!.first as! ErrorView
        view.translatesAutoresizingMaskIntoConstraints = false
        view.retryButton.addTarget(self, action: #selector(retry(_:)), forControlEvents: .TouchUpInside)
        return view
    }()
    
    func presentError(error: Error) {
        errorView.error = error
        view.addSubview(errorView)
        installErrorViewConstraints()
    }
    
    func installErrorViewConstraints() {
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[view]|", options: [], metrics: nil, views: ["view": errorView]))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[view]|", options: [], metrics: nil, views: ["view": errorView]))
    }
    
    func retry(sender: AnyObject) {
        errorView.removeFromSuperview()
        reloadVisitable()
    }
    
    private func share(textToShare: String, url: NSURL) {
        let objectsToShare = [textToShare, url]
        let activityViewController = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
        self.presentViewController(activityViewController, animated: true, completion: nil)
    }
}

// MARK: - 帖子相关功能

extension WebViewController {
    
    private func addTopicActionButton() {
        var rightBarButtonItems = self.navigationItem.rightBarButtonItems ?? [UIBarButtonItem]()
        
        if OAuth2.shared.isLogined {
            topicFavoriteButton = UIBarButtonItem(image: UIImage(named: "bookmark"), style: .Plain, target: self, action: #selector(self.topicFavoriteAction))
            rightBarButtonItems.append(topicFavoriteButton!)
            
            topicFollowButton = UIBarButtonItem(image: UIImage(named: "invisible"), style: .Plain, target: self, action: #selector(self.topicFollowAction))
            rightBarButtonItems.append(topicFollowButton!)
        }
        
        topicLikeButton = UIBarButtonItem(image: UIImage(named: "like"), style: .Plain, target: self, action: #selector(self.topicLikeAction))
        rightBarButtonItems.append(topicLikeButton!)
        
        self.navigationItem.rightBarButtonItems = rightBarButtonItems
    }
    
    private func loadTopicActionButtonStatus() {
        
    }
    
    func topicFavoriteAction() {
        guard let button = topicFavoriteButton, id = topicID else {
            return
        }
        
        func callback(statusCode: Int?) {
            guard let code = statusCode where code == 200 else {
                return
            }
            button.tag = button.tag == 0 ? 1 : 0;
            button.image = UIImage(named: button.tag == 0 ? "bookmark-filled" : "bookmark")
            RBHUD.success((button.tag == 0 ? "favorited" : "cancelled").localized)
        }
        
        if button.tag == 0 {
            TopicsService.favorite(id, callback: callback)
        } else {
            TopicsService.unfavorite(id, callback: callback)
        }
    }
    
    func topicFollowAction() {
        guard let button = topicFollowButton, id = topicID else {
            return
        }
        
        func callback(statusCode: Int?) {
            guard let code = statusCode where code == 200 else {
                return
            }
            button.tag = button.tag == 0 ? 1 : 0;
            button.image = UIImage(named: button.tag == 0 ? "invisible-filled" : "invisible")
            RBHUD.success((button.tag == 0 ? "followed" : "cancelled").localized)
        }
        
        if button.tag == 0 {
            TopicsService.follow(id, callback: callback)
        } else {
            TopicsService.unfollow(id, callback: callback)
        }
    }
    
    func topicLikeAction() {
        
    }
    
}
