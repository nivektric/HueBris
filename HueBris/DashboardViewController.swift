//
//  DashboardViewController.swift
//  HueBris
//
//  Created by Kevin Monahan on 8/4/16.
//  Copyright © 2016 Intrepid Pursuits. All rights reserved.
//

import Foundation

class DashboardViewController: UIViewController {
    
    private let groupCellReuseIdentifier = "GroupTableViewCell"
    private let groupControlSegueIdentifier = "GroupControl"
    private let groupControlStoryboardIdentifier = "GroupControlViewController"

    @IBOutlet private weak var tableView: UITableView!
    
    private var groups = [PHGroup]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Groups"
        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: groupCellReuseIdentifier)
        
        NSNotificationCenter.defaultCenter().addObserver(self,
                                                         selector: #selector(groupsUpdated),
                                                         name: Bridge.GroupsUpdatedNotification,
                                                         object: Bridge.sharedInstance)
        Bridge.sharedInstance.connect { 
            print("Done!")
        }
    }
    
    @IBAction func allRed(sender: AnyObject) {
        Bridge.sharedInstance.setAllLightsToColor(UIColor.redColor())
    }
    
    func groupsUpdated() {
        groups = Bridge.sharedInstance.allGroups()
        tableView.reloadData()
    }

}

extension DashboardViewController: UITableViewDataSource {
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(groupCellReuseIdentifier, forIndexPath: indexPath)
        
        cell.textLabel?.text = groups[indexPath.row].name
        
        return cell
    }
    
}

extension DashboardViewController: UITableViewDelegate {
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let group = groups[indexPath.row]
        guard let controller = storyboard?.instantiateViewControllerWithIdentifier("GroupControlViewController") as? GroupControlViewController else { return }
        controller.group = group
        navigationController?.pushViewController(controller, animated: true)
    }
    
}