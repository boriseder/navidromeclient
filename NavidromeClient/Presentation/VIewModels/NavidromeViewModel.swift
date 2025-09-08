import Foundation
import SwiftUI

@MainActor
class NavidromeViewModel: ObservableObject {
    // MARK: - Daten
    @Published var artists: [Artist] = []
    @Published var albums: [Album] = []
    @Published var songs: [Song] = []
    @Published var genres: [Genre] = []
    @Published var albumSongs: [String: [Song]] = [:]

    @Published var isLoading = false
    @Published var connectionStatus = false
    @Published var errorMessage: String?

    @Published var serverType: String?
    @Published var serverVersion: String?
    @Published var subsonicVersion: String?
    @Published var openSubsonic: Bool?

    
    // MARK: - Credentials / UI Bindings
    @Published var scheme: String = "http"
    @Published var host: String = ""
    @Published var port: String = ""
    @Published var username: String = ""
    @Published var password: String = ""

    // MARK: - Dependencies
    private var service: SubsonicService?
    private let downloadManager: DownloadManager

    // MARK: - Init with Dependency Injection
    init(downloadManager: DownloadManager = .shared) {
        self.downloadManager = downloadManager
        loadSavedCredentials()
    }

    // MARK: - Service Management
    func updateService(_ newService: SubsonicService) {
        self.service = newService
    }
    
    func getService() -> SubsonicService? {
        return service
    }

    // MARK: - Credentials Management
    private func loadSavedCredentials() {
        if let creds = AppConfig.shared.getCredentials() {
            self.scheme = creds.baseURL.scheme ?? "http"
            self.host = creds.baseURL.host ?? ""
            self.port = creds.baseURL.port.map { String($0) } ?? ""
            self.username = creds.username
            self.password = creds.password
            
            self.service = SubsonicService(
                baseURL: creds.baseURL,
                username: creds.username,
                password: creds.password
            )
        }
    }

    // MARK: - Verbindungstest mit aktuellen Eingaben
    func testConnection() async {
        guard let url = buildCurrentURL() else {
            print("❌ Ungültige URL")
            connectionStatus = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        let tempService = SubsonicService(baseURL: url, username: username, password: password)

        do {
            let response = try await tempService.pingWithInfo() // Methode im Service, die Ping-Response parsed
            connectionStatus = true
            
            // Infos speichern
            subsonicVersion = response.version
            serverType = response.type
            serverVersion = response.serverVersion
            openSubsonic = response.openSubsonic
            
            print("✅ Verbindung erfolgreich")
        } catch {
            connectionStatus = false
            errorMessage = "Verbindung fehlgeschlagen"
            print("❌ Verbindung fehlgeschlagen: \(error)")
        }
    }

    // MARK: - Speichern der Credentials
    func saveCredentials() async -> Bool {
        guard let url = buildCurrentURL() else {
            errorMessage = "Ungültige URL"
            return false
        }

        let tempService = SubsonicService(baseURL: url, username: username, password: password)
        
        isLoading = true
        defer { isLoading = false }
        
        let success = await tempService.ping()
        connectionStatus = success
        
        guard success else {
            errorMessage = "Verbindung mit den eingegebenen Daten fehlgeschlagen"
            return false
        }

        // Credentials speichern
        AppConfig.shared.configure(baseURL: url, username: username, password: password)

        // Service aktualisieren
        self.service = tempService

        print("✅ Credentials gespeichert und Service konfiguriert")
        return true
    }
    
    // MARK: - Helper
    private func buildCurrentURL() -> URL? {
        let portString = port.isEmpty ? "" : ":\(port)"
        return URL(string: "\(scheme)://\(host)\(portString)")
    }
    
    // MARK: - Service-Aufrufe
    func loadArtists() async {
        guard let service else {
            print("❌ Service nicht verfügbar")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            artists = try await service.getArtists()
        } catch {
            errorMessage = "Failed to load artists: \(error.localizedDescription)"
            print("Failed to load artists: \(error)")
        }
    }

    func loadAlbums(context: ArtistDetailContext) async throws -> [Album] {
        guard let service else { throw URLError(.networkConnectionLost) }
        
        switch context {
        case .artist(let artist):
            return try await service.getAlbumsByArtist(artistId: artist.id)
        case .genre(let genre):
            return try await service.getAlbumsByGenre(genre: genre.value)
        }
    }

    func loadSongs(for albumId: String) async -> [Song] {
        guard let service else { return [] }

        if let cached = albumSongs[albumId], !cached.isEmpty {
            return cached
        }

        do {
            let songs = try await service.getSongs(for: albumId)
            albumSongs[albumId] = songs
            return songs
        } catch {
            errorMessage = "Failed to load songs: \(error.localizedDescription)"
            print("Failed to load songs: \(error)")
            return []
        }
    }

    func loadCoverArt(for albumId: String, size: Int = 300) async -> UIImage? {
        guard let service else { return nil }
        return await service.getCoverArt(for: albumId, size: size)
    }

    func loadGenres() async {
        guard let service else { return }
        do {
            genres = try await service.getGenres()
        } catch {
            errorMessage = "Failed to load genres: \(error.localizedDescription)"
            print("Failed to load genres: \(error)")
        }
    }

    func search(query: String) async {
        guard let service else { return }

        if query.isEmpty {
            artists = []
            albums = []
            songs = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await service.search(query: query)
            artists = result.artists
            albums = result.albums
            songs = result.songs
        } catch {
            artists = []
            albums = []
            songs = []
            errorMessage = "Fehler bei der Suche: \(error.localizedDescription)"
        }
    }

    func downloadAlbum(songs: [Song], albumId: String, playerVM: PlayerViewModel) async {
        guard let service else { return }
        await downloadManager.downloadAlbum(songs: songs, albumId: albumId, service: service)
    }
    
    // MARK: - Reset
    func reset() {
        service = nil
        artists = []
        albums = []
        songs = []
        genres = []
        albumSongs = [:]
        scheme = "http"
        host = ""
        port = ""
        username = ""
        password = ""
        connectionStatus = false
        errorMessage = nil
    }
}
