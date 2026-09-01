/// Friendly offline copy — one line is picked at random when the device is offline.
import 'dart:math';

const offlineMessages = <String>[
  "You're offline right now — reconnect and we'll pick up where we left off.",
  "No internet at the moment. Your vault on this device is still safe.",
  "Can't reach the cloud just yet. A quick connection check might help.",
  "Looks like you're off the grid. Try again once you're back online.",
  "The network seems quiet — we'll sync again when you're connected.",
  "Offline for now. Nucleus will be ready as soon as your connection returns.",
  "We couldn't reach the server. Wi‑Fi or mobile data might need a nudge.",
  "Connection's down, but nothing on this device is at risk.",
  "Taking a break from the internet? Reconnect when you're ready to continue.",
  "Can't talk to the cloud right now — give it another go once you're online.",
  "Your secrets are fine here; we just need internet to sync with the server.",
  "Signal's missing in action. Check your connection and try once more.",
];

final _random = Random();

/// Returns a different friendly offline line each time it's called.
String randomOfflineMessage() {
  return offlineMessages[_random.nextInt(offlineMessages.length)];
}
