# lumvero-ios-pipeline-test

Technischer Test einer iOS-Build-Pipeline, **keine App**. Nicht zur Einreichung im App Store gedacht.

- Minimales SwiftUI-Projekt „PipelineTest“ (iPhone + iPad, iOS 17.0+), erzeugt mit [XcodeGen](https://github.com/yonaskolb/XcodeGen) aus `project.yml`.
- Lokale JSON-Speicherung, Eingabevalidierung, adaptive Oberfläche (NavigationSplitView auf iPad, NavigationStack auf iPhone).
- Einmaliger Test-Kauf „Pro“ über StoreKit 2 – nur gegen die lokale Datei `StoreKit/Products.storekit` (kein echtes Produkt).
- GitHub Actions (`.github/workflows/ios.yml`): unsignierter Build + Archiv für `generic/platform=iOS`, Unit-, StoreKit- und UI-Tests auf iPhone- und iPad-Simulator, Screenshots als Artefakt.
- Ein Signier-/Upload-Job ist vorbereitet, aber mit `if: false` deaktiviert. Es sind keine Secrets hinterlegt.

Bundle-ID `digital.lumvero.pipelinetest` ist ein Platzhalter.
