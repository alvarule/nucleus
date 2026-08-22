/// Local password generator for the Generator tab.
import 'dart:math';

class PasswordGenerator {
  PasswordGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  /// Guarantees at least one char from each selected set, then fills and shuffles.
  String generate({
    int length = 16,
    bool lower = true,
    bool upper = true,
    bool numbers = true,
    bool symbols = true,
  }) {
    final buffers = <String>[];
    if (lower) buffers.add('abcdefghijklmnopqrstuvwxyz');
    if (upper) buffers.add('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
    if (numbers) buffers.add('0123456789');
    if (symbols) buffers.add(r'!@#$%^&*()-_=+[]{};:,.?/');
    if (buffers.isEmpty || length < 4) {
      throw ArgumentError('Select at least one character set and length >= 4');
    }
    final all = buffers.join();
    final chars = <String>[];
    for (final set in buffers) {
      chars.add(set[_random.nextInt(set.length)]);
    }
    while (chars.length < length) {
      chars.add(all[_random.nextInt(all.length)]);
    }
    chars.shuffle(_random);
    return chars.join();
  }
}
