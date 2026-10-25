// Config.swift
// Virtual configuration view for optional API gateway endpoints.
// Safe defaults for open-source compilation.

import Foundation

enum Config {
    nonisolated static let AI_GATEWAY_SECRET_KEY = ""
    nonisolated static let AI_GATEWAY_URL = ""

    nonisolated static let allValues: [String: String] = [
        "AI_GATEWAY_SECRET_KEY": AI_GATEWAY_SECRET_KEY,
        "AI_GATEWAY_URL": AI_GATEWAY_URL,
    ]
}
