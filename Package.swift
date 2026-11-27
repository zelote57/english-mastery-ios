// Package.swift
// Swift Package Manager manifest for the English Mastery iOS project.
// Adds the Google Generative AI Swift SDK for on‑device Gemini embeddings.

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EnglishMastery",
    platforms: [.iOS(.v17)],
    products: [
        .library(
            name: "EnglishMastery",
            targets: ["EnglishMastery"]
        )
    ],
    dependencies: [
        // Google Generative AI Swift SDK (includes on‑device Gemini models)
        .package(url: "https://github.com/google/generative-ai-swift.git", from: "0.2.0")
    ],
    targets: [
        .target(
            name: "EnglishMastery",
            path: "iosApp/Sources",
            resources: [.process("Data/VectorStore")]
        )
    ]
)
