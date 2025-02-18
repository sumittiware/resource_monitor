import Flutter
import UIKit

public class SwiftResourceMonitorPlugin: NSObject, FlutterPlugin {
    public typealias MemoryUsage = (used: UInt64, total: UInt64)
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "resource_monitor", binaryMessenger: registrar.messenger())
        let instance = SwiftResourceMonitorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if(call.method == "getResourceUsage")
        {
            var mem = memoryInUseByOs()
            var dict = [String: Any]()
            dict["memoryInUseByApp"] = memoryInUseByApp()
            dict["memeoryInUseByOs"] = mem.used
            dict["memoryFree"] = deviceRemainingFreeSpace()
            dict["totalMemory"] = mem.total
            dict["cpuInUseByApp"] = cpuInUseByApp()
            
            result(dict)
        }
        else
        {
            result("iOS could not recognize flutter call for: " + call.method)
            return
        }
    }
    

    public func cpuInUseByApp() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            return $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }
        
        if threadsResult == KERN_SUCCESS, let threadsList = threadsList {
            for index in 0..<threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }
                
                guard infoResult == KERN_SUCCESS else {
                    break
                }
                
                let threadBasicInfo = threadInfo as thread_basic_info
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU = (totalUsageOfCPU + (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0))
                }
            }
        }
        
        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        return totalUsageOfCPU
    }
    

    func memoryInUseByApp() -> Double {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(taskInfo.resident_size)
        }
        else {
            print("Error with task_info(): " +
                    (String(cString: mach_error_string(kerr), encoding: String.Encoding.ascii) ?? "unknown error"))
        }
        return 0.0
    }

    public func memoryInUseByOs() -> MemoryUsage {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        var used: UInt64 = 0
        if result == KERN_SUCCESS {
            used = UInt64(taskInfo.phys_footprint)
        }
        
        let total = ProcessInfo.processInfo.physicalMemory
        return (used, total)
    }

    // Free space in file system
    public func deviceRemainingFreeSpace() -> Int64? {
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last!
            guard
                let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: documentDirectory),
                let freeSize = systemAttributes[.systemFreeSize] as? NSNumber
            else {
                return nil
            }
        return freeSize.int64Value 
    }
}
