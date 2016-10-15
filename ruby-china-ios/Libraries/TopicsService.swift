//
//  TopicsService.swift
//  ruby-china-ios
//
//  Created by 柯磊 on 16/10/9.
//  Copyright © 2016年 ruby-china. All rights reserved.
//

class TopicsService {

    /// list接口排序类型
    ///
    /// - last_actived: 最近回复
    /// - recent:       最近的
    /// - no_reply:     无回复的
    /// - popular:      受欢迎的
    /// - excellent:    精华
    enum ListType: String {
        case last_actived
        case recent
        case no_reply
        case popular
        case excellent
    }
    
    /// 获取帖子列表
    ///
    /// - parameter type:     排序类型
    /// - parameter node_id:  节点编号，传大于 0 时返回该节点的帖子
    /// - parameter offset:   分页起始位置
    /// - parameter limit:    分页大小，范围 1..150
    /// - parameter callback: 完成时回调
    static func list(type: ListType = .last_actived, node_id: Int = 0, offset: Int = 0, limit: Int = 20, callback: (statusCode: Int?, result: [Topic]?) -> ()) {
        
        var parameters = [String: AnyObject]()
        parameters["type"] = type.rawValue
        parameters["offset"] = offset
        parameters["limit"] = limit
        if node_id > 0 {
            parameters["node_id"] = node_id
        }
        
        APIRequest.shared.get("/api/v3/topics.json", parameters: parameters) { (statusCode, result) in
            guard let _ = result, topicList = result!["topics"].array where topicList.count > 0 else {
                callback(statusCode: statusCode, result: nil)
                return
            }
            
            var topics = [Topic]()
            for topicJSON in topicList {
                topics.append(Topic(json: topicJSON))
            }
            
            callback(statusCode: statusCode, result: topics)
        }
    }
    
}
