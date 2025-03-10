import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "It works!"
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
    
    app.get("cpu") { req async throws -> String in
        startCPUProfiling(filename: "cpu_profile.out")
        try await Task.sleep(for: .seconds(5))
        stopCPUProfiling()
        return "Done!"
    }
    
    app.get("heap") { req async throws -> String in
        // jemallocProfilerStart()
        // try await Task.sleep(for: .seconds(5))
        // jemallocProfilerStop()
        jemallocProfilerDump(to: "jemalloc-runtime-profile.heap")
        return "Done!"
    }
}
