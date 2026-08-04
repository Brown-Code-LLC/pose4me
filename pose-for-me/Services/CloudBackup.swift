import CloudKit
import Combine
import Foundation

/// Backs up session history to the user's private CloudKit database as a single
/// record carrying sessions.json. On every sync the remote archive is merged
/// into the local store (union by record id), then the union is pushed back —
/// so a new phone restores streaks and shields, and two devices converge.
/// No accounts, no server: just the user's own iCloud.
@MainActor
final class CloudBackup: ObservableObject {
    // Xcode 26.2's Swift runtime intermittently aborts in the isolated-deinit
    // executor hop when MainActor classes deallocate; opt out (see SessionStore).
    nonisolated deinit {}

    enum Status: Equatable {
        case idle
        case syncing
        case upToDate(Date)
        case unavailable      // no iCloud account signed in
        case failed(String)
    }

    @Published private(set) var status: Status = .idle

    private static let containerID = "iCloud.com.browncode.pose4me"
    private static let recordType = "SessionArchive"
    private static let recordName = "sessions"
    private static let payloadKey = "payload"

    private var syncTask: Task<Void, Never>?

    /// Merge-and-push, coalesced: calls while a sync is running are dropped
    /// (the running pass already pushes the latest store state at save time).
    func sync(store: SessionStore) {
        guard syncTask == nil else { return }
        syncTask = Task { [weak self] in
            await self?.performSync(store: store, attempt: 0)
            self?.syncTask = nil
        }
    }

    private func performSync(store: SessionStore, attempt: Int) async {
        status = .syncing
        let container = CKContainer(identifier: Self.containerID)
        do {
            guard try await container.accountStatus() == .available else {
                status = .unavailable
                return
            }
            let database = container.privateCloudDatabase
            let recordID = CKRecord.ID(recordName: Self.recordName)

            var record: CKRecord
            var remoteRecords: [SessionRecord] = []
            do {
                record = try await database.record(for: recordID)
                if let asset = record[Self.payloadKey] as? CKAsset,
                   let url = asset.fileURL,
                   let data = try? Data(contentsOf: url) {
                    remoteRecords = (try? JSONDecoder().decode([SessionRecord].self, from: data)) ?? []
                }
            } catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: Self.recordType, recordID: recordID)
            }

            store.merge(remote: remoteRecords)

            // Push only when the union differs from what iCloud already holds.
            if Set(remoteRecords.map(\.id)) != Set(store.records.map(\.id)) {
                let data = try JSONEncoder().encode(store.records)
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("pose4me-backup-\(UUID().uuidString).json")
                try data.write(to: tmp, options: .atomic)
                defer { try? FileManager.default.removeItem(at: tmp) }
                record[Self.payloadKey] = CKAsset(fileURL: tmp)
                _ = try await database.save(record)
            }
            status = .upToDate(Date())
        } catch let error as CKError where error.code == .serverRecordChanged && attempt < 2 {
            // Another device wrote first — refetch, remerge, retry.
            await performSync(store: store, attempt: attempt + 1)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
