//
//  ServiceTaskRetrofitterTests.swift
//  ConduletTests
//
//  Created by Natan Zalkin on 05/10/2018.
//  Copyright © 2018 Natan Zalkin. All rights reserved.
//

import Quick
import Nimble
import Mockingjay
import SwiftProtobuf

@testable import Condulet

class ServiceTaskRetrofitterTests: QuickSpec, ServiceTaskRetrofitting {

    enum Errors: Error {
        case test
    }

    var requestHandler: ((ServiceTask, inout URLRequest) throws -> Bool)?
    var responseHandler: ((ServiceTask) throws -> Bool)?
    var errorHandler: ((ServiceTask) throws -> Bool)?

    var shouldFailRequest = false
    var shouldFailResponse = false


    func shouldInterceptRequest(_ request: inout URLRequest, for task: ServiceTask, with action: ServiceTaskAction) throws -> Bool {
        if shouldFailRequest { throw Errors.test }
        return try requestHandler?(task, &request) ?? false
    }

    func shouldInterceptContent(_ content: ServiceTaskContent, for task: ServiceTask, with response: URLResponse) throws -> Bool {
        if shouldFailResponse { throw Errors.test }
        return try responseHandler?(task) ?? false
    }

    func shouldInterceptError(_ error: Error, for task: ServiceTask, with response: URLResponse?) throws -> Bool {
        return try errorHandler?(task) ?? false
    }

    override func spec() {

        describe("ServiceTaskInterception") {

            afterEach {
                self.shouldFailRequest = false
                self.shouldFailResponse = false
                self.requestHandler = nil
                self.responseHandler = nil
                self.errorHandler = nil
                self.removeAllStubs()
            }

            it("can intercept request") {

                self.stub(http(.get, uri: "test.intercept.request"), json(["test": "ok"]))

                waitUntil { (done) in

                    self.requestHandler = { (task, request) in
                        request.url = URL(string: "test.intercept.request")
                        try task.sendRequest(request)
                        return true
                    }

                    ServiceTaskBuilder(retrofitter: self)
                        .endpoint(.GET, "test.test")
                        .content { (content, response) in
                            done()
                        }
                        .error { (error, response) in
                            fail("\(error)")
                        }
                        .perform()

                }
            }

            it("can fail request") {

                self.stub(http(.get, uri: "test.fail.request"), json(["test": "ok"]))
                self.shouldFailRequest = true

                waitUntil { (done) in

                    ServiceTaskBuilder(retrofitter: self)
                        .endpoint(.GET, "test.fail.request")
                        .content { (content, response) in
                            fail("Request should return error!")
                        }
                        .error { (error, response) in
                            switch error {
                            case Errors.test:
                                done()
                            default:
                                fail("Request should return test error!")
                            }
                        }
                        .perform()

                }
            }

            it("can intercept error") {

                // No stub will fail

                waitUntil { (done) in

                    self.errorHandler = { (task) in
                        throw Errors.test
                    }

                    ServiceTaskBuilder(retrofitter: self)
                        .endpoint(.GET, "test.failed")
                        .content { (content, response) in
                            fail("Request should return error!")
                        }
                        .error { (error, response) in
                            switch error {
                            case Errors.test:
                                done()
                            default:
                                fail("Request should return test error!")
                            }
                        }
                        .perform()

                }
            }

            it("can intercept response") {

                self.stub(http(.get, uri: "test.intercept.response"), json(["test": "ok"]))

                waitUntil { (done) in

                    self.responseHandler = { (task) in
                        throw Errors.test
                    }

                    ServiceTaskBuilder(retrofitter: self)
                        .endpoint(.GET, "test.intercept.response")
                        .content { (content, response) in
                            fail("Request should return error!")
                        }
                        .error { (error, response) in
                            switch error {
                            case Errors.test:
                                done()
                            default:
                                fail("Request should return test error!")
                            }
                        }
                        .perform()

                }
            }
        }
    }
}
