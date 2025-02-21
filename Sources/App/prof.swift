//
//  prof.swift
//  perf
//
//  Created by Brian Floersch on 2/19/25.
//
import Glibc

@_silgen_name("ProfilerStart")
func ProfilerStart(_ fname: UnsafePointer<CChar>?) -> Int32

@_silgen_name("ProfilerStop")
func ProfilerStop()

func startCPUProfiling(filename: String = "cpu_profile.out") {
    _ = filename.withCString { ProfilerStart($0) }
}

func stopCPUProfiling() {
    ProfilerStop()
}

// jeprof

@_silgen_name("mallctl")
func mallctl(_ name: UnsafePointer<CChar>,
             _ oldp: UnsafeMutableRawPointer?,
             _ oldlenp: UnsafeMutablePointer<Int>?,
             _ newp: UnsafeMutableRawPointer?,
             _ newlen: Int) -> Int32

func jemallocProfilerStart() {
    var active: Int32 = 1
    let name = "prof.active"
    var size = MemoryLayout.size(ofValue: active)
    let result = name.withCString { cName in
        withUnsafeMutablePointer(to: &active) { newp in
            mallctl(cName, nil, nil, newp, size)
        }
    }
    if result != 0 {
        perror("Failed to start jemalloc profiling")
    } else {
        print("jemalloc profiling started.")
    }
}

func jemallocProfilerStop() {
    var active: Int32 = 0
    let name = "prof.active"
    var size = MemoryLayout.size(ofValue: active)
    let result = name.withCString { cName in
        withUnsafeMutablePointer(to: &active) { newp in
            mallctl(cName, nil, nil, newp, size)
        }
    }
    if result != 0 {
        perror("Failed to stop jemalloc profiling")
    } else {
        print("jemalloc profiling stopped.")
    }
}

func jemallocProfilerDump(to path: String) {
    var cPath = strdup(path)
    defer { free(cPath) }
    let result = "prof.dump".withCString { cName in
        mallctl(cName, nil, nil, &cPath, MemoryLayout.size(ofValue: cPath))
    }
    if result != 0 {
        perror("Failed to dump jemalloc profile")
    } else {
        print("jemalloc profile dumped to \(path)")
    }
}