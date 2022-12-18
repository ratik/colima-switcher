//
//  AppDelegate.swift
//  lima
//
//  Created by Ratiashvili Sergey on 17.12.22..
//

import Cocoa
import Foundation

enum CmdError: Error {
    case Failed
}

struct LimaOut: Decodable {
    let name: String
    let status: String
    let arch: String
}

func execCMD(cmd: String) throws -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    task.arguments = ["-l", "-c", cmd]
    let outputPipe = Pipe()
    task.standardOutput = outputPipe
    
    task.launch()
    task.waitUntilExit()

    if task.terminationStatus == 0 {
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            return output
        }
    } else {
        throw CmdError.Failed
    }
    return ""
}


func getLimaInstances() -> (Array<LimaOut>) {
    do {
        let out = try execCMD(cmd: "colima list --json")
        let lines = out.split(separator: "\n")
        return try lines.map {
            let data = $0.data(using: .utf8)!
            let json = try JSONDecoder().decode(LimaOut.self, from: data)
            return json
        }
    } catch {
        return []
    }
}




@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?
    var instances: Array<LimaOut> = []
    var currentTitle = "(~)"
    
    @objc func selectItem(item: NSMenuItem) {
        let selectedInstance = item.representedObject as! LimaOut
        self.updateTitle(title: "...")
        
        for instance in instances {
            if instance.name != selectedInstance.name {
                do {
                    try execCMD(cmd: "colima stop -p " + instance.name)
                } catch {}
            } else {
                do {
                    try execCMD(cmd: "colima start -p " + instance.name)
                } catch {}
            }
        }
        
        var dockerContextName = "colima"
        if (selectedInstance.name != "default") {
            dockerContextName += "-"+selectedInstance.name
        }
        do {
            try execCMD(cmd: "docker conext use " + dockerContextName)
        } catch { }
        self.updateTitle(title: selectedInstance.arch)
        drawMenu()
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    func updateTitle(title: String) {
        self.currentTitle = title
        statusItem?.button?.title = title
    }
    
    func drawMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = currentTitle
        let menu = NSMenu()
        instances = getLimaInstances()
        for instance in instances {
            let item = NSMenuItem(title: instance.name+"\t"+instance.arch+"\t\t"+instance.status, action:  #selector(self.selectItem), keyEquivalent: "")
            item.target = self
            item.representedObject = instance
            menu.addItem(item)
        }
        
        let q = NSMenuItem(title: "quit", action:  #selector(self.quit), keyEquivalent: "q")
        menu.addItem(q)
        statusItem?.menu=menu
    }
    
    func detectCurrentConext() {
        do {
            var profile = ( try execCMD(cmd: "docker context ls | grep '*' | grep colima") );
            if (profile == "") { return }
            
            profile = profile.replacingOccurrences(of: "^colima[-]*([\\w]*)\\s.*$", with: "$1", options: .regularExpression).trimmingCharacters(in: .newlines)
            if (profile.isEmpty) {
                profile = "default"
            }
            let index = instances.firstIndex(where: {
                return $0.name == profile
            })
            if let index = index {
                let instance = instances[index]
                self.updateTitle(title: instance.arch)
            }
        } catch {}
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        drawMenu()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        instances = getLimaInstances()
        self.detectCurrentConext()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

