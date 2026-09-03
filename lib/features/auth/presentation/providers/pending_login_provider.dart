/// Holds master password between Auth sign-in and login TOTP verification.
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pendingLoginPasswordProvider = StateProvider<String?>((ref) => null);
