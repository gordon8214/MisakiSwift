// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Contextual English frontend with Accelerate inference and frontend-owned tokens.
// Explicit resource copies keep the iOS bundle flat.
let package = Package(
  name: "MisakiSwift",
  platforms: [
    .iOS(.v18), .macOS(.v15)
  ],
  products: [
    .library(
      name: "MisakiSwift",
      type: .dynamic,
      targets: ["MisakiSwift"]
    ),
  ],
  targets: [
    .target(
      name: "MisakiSwift",
     resources: [
      .copy("../../Resources/MLXUtilsLibrary_LICENSE"),
      .copy("../../Resources/gb_bart.safetensors"),
      .copy("../../Resources/gb_bart_config.json"),
      .copy("../../Resources/gb_gold.json"),
      .copy("../../Resources/gb_silver.json"),
      .copy("../../Resources/us_bart.safetensors"),
      .copy("../../Resources/us_bart_config.json"),
      .copy("../../Resources/us_gold.json"),
      .copy("../../Resources/us_silver.json"),
      .copy("../../Resources/spacy_tagger.safetensors"),
      .copy("../../Resources/spacy_tokenizer.json"),
      .copy("../../Resources/spacy_tagger.json"),
      .copy("../../Resources/spacy_LICENSE"),
      .copy("../../Resources/spacy_LICENSES_SOURCES")
     ]
    ),
    .testTarget(
      name: "MisakiSwiftTests",
      dependencies: ["MisakiSwift"],
      resources: [
      .copy("../../Resources/MLXUtilsLibrary_LICENSE"),
        .copy("Fixtures/spacy_parity_sentences.txt"),
        .copy("Fixtures/spacy_parity_trace.json"),
        .copy("Fixtures/frontend_token_parity.json")
      ]
    ),
  ]
)
