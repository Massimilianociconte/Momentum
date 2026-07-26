import Foundation

/// Coda persistente phone-side per gli eventi ricevuti da Apple Watch.
///
/// Il payload viene salvato prima di invocare Dart e rimosso solo dopo la
/// conferma del merge. In caso di chiusura o crash del motore Flutter, la coda
/// viene riletta al successivo avvio e il repository Dart deduplica per
/// `eventId`.
final class AppleWatchEventQueue {
  struct Item: Codable, Equatable {
    let queueId: String
    let matchId: String
    let events: String
    let format: String?
  }

  private static let defaultKey = "rallymate.apple_watch.pending_events.v1"
  private static let maximumItems = 256

  private let defaults: UserDefaults
  private let key: String
  private let lock = NSLock()

  init(defaults: UserDefaults = .standard, key: String = defaultKey) {
    self.defaults = defaults
    self.key = key
  }

  @discardableResult
  func enqueue(matchId: String, events: String, format: String?) -> String? {
    locked {
      // A malformed persisted queue is not the same as an empty queue. Treat
      // it as unavailable so a new event cannot overwrite unacknowledged data
      // and accidentally earn an ACK from the bridge.
      guard var items = loadUnlocked() else { return nil }
      if let duplicate = items.last(where: {
        $0.matchId == matchId && $0.events == events && $0.format == format
      }) {
        return duplicate.queueId
      }

      // Backpressure is safer than evicting a score batch that the watch may
      // delete after our ACK. A full queue returns no id, so the bridge replies
      // `ok: false` and the watch retains its durable journal for a later retry.
      guard items.count < Self.maximumItems else { return nil }
      let item = Item(
        queueId: UUID().uuidString,
        matchId: matchId,
        events: events,
        format: format
      )
      items.append(item)
      guard saveUnlocked(items) else { return nil }
      return item.queueId
    }
  }

  func pendingJSON() -> String? {
    locked {
      guard let items = loadUnlocked() else { return nil }
      return encode(items)
    }
  }

  @discardableResult
  func replace(with json: String) -> Bool {
    locked {
      // Never replace storage that we cannot decode: the bytes may contain
      // the only durable copy of events already sent by the watch.
      guard loadUnlocked() != nil,
            let data = json.data(using: .utf8),
            let decoded = try? JSONDecoder().decode([Item].self, from: data),
            decoded.count <= Self.maximumItems
      else {
        return false
      }
      saveUnlocked(decoded)
      return true
    }
  }

  @discardableResult
  func acknowledge(_ queueId: String) -> Bool {
    locked {
      guard let items = loadUnlocked() else { return false }
      let remaining = items.filter { $0.queueId != queueId }
      saveUnlocked(remaining)
      return true
    }
  }

  /// `[]` means the key is genuinely absent; `nil` means persisted data exists
  /// but is malformed or has an unexpected type.
  private func loadUnlocked() -> [Item]? {
    guard let stored = defaults.object(forKey: key) else { return [] }
    guard let data = stored as? Data else { return nil }
    return try? JSONDecoder().decode([Item].self, from: data)
  }

  @discardableResult
  private func saveUnlocked(_ items: [Item]) -> Bool {
    guard !items.isEmpty else {
      defaults.removeObject(forKey: key)
      return true
    }
    guard let data = try? JSONEncoder().encode(items) else { return false }
    defaults.set(data, forKey: key)
    return true
  }

  private func encode(_ items: [Item]) -> String? {
    guard let data = try? JSONEncoder().encode(items) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private func locked<T>(_ operation: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return operation()
  }
}
