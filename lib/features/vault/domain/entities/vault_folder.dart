/// Single-level folder for organizing vault items. Names are not encrypted.
import 'package:equatable/equatable.dart';

class VaultFolder extends Equatable {
  const VaultFolder({
    required this.id,
    required this.userId,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  VaultFolder copyWith({String? name, int? sortOrder}) {
    return VaultFolder(
      id: id,
      userId: userId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, name, sortOrder, createdAt, updatedAt];
}
