// APIClient.swift

import Foundation
import os

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
}

struct EmptyAPIResponse: Decodable {}

enum APIError: LocalizedError {
    case invalidURL(String)
    case unexpectedResponse
    case httpError(statusCode: Int, body: String?)
    case decodingFailed(Error)
    case encodingFailed(Error)
    case noNetwork

    var errorDescription: String? {
        switch self {
        case .invalidURL(let path):
            return "Invalid URL path: \(path)"
        case .unexpectedResponse:
            return "Unexpected server response"
        case .httpError(let code, _):
            return "Server returned \(code)"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Encoding failed: \(error.localizedDescription)"
        case .noNetwork:
            return "No network connection"
        }
    }
}

actor APIClient {
    let environment: AppEnvironment
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let logger = AppLogger.make(.api)

    init(environment: AppEnvironment) {
        self.environment = environment
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func get<T: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        try await send(path, method: .get, queryItems: queryItems)
    }

    func post<T: Decodable, Body: Encodable>(
        _ path: String,
        body: Body,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        let data = try encode(body)
        return try await send(path, method: .post, queryItems: queryItems, body: data)
    }

    func patch<T: Decodable, Body: Encodable>(
        _ path: String,
        body: Body,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        let data = try encode(body)
        return try await send(path, method: .patch, queryItems: queryItems, body: data)
    }

    private func send<T: Decodable>(
        _ path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) async throws -> T {
        let request = try buildRequest(path: path, method: method, queryItems: queryItems, body: body)

        logger.debug("\(method.rawValue, privacy: .public) \(path, privacy: .public)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet {
            throw APIError.noNetwork
        }

        try validateHTTPResponse(response, data: data, path: path)

        if T.self == EmptyAPIResponse.self {
            return EmptyAPIResponse() as! T
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("Decode error for \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw APIError.decodingFailed(error)
        }
    }

    private func buildRequest(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem]?,
        body: Data?
    ) throws -> URLRequest {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        if !environment.anonKey.isEmpty {
            request.setValue("Bearer \(environment.anonKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func encode<Body: Encodable>(_ body: Body) throws -> Data {
        do {
            return try encoder.encode(body)
        } catch {
            throw APIError.encodingFailed(error)
        }
    }

    private func buildURL(path: String, queryItems: [URLQueryItem]?) throws -> URL {
        guard var components = URLComponents(
            url: environment.apiBaseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL(path)
        }
        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL(path)
        }
        return url
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data, path: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unexpectedResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            logger.error("HTTP \(http.statusCode) for \(path, privacy: .public): \(body ?? "nil", privacy: .public)")
            throw APIError.httpError(statusCode: http.statusCode, body: body)
        }
    }
}
