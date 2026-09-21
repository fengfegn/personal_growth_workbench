sealed class AppError implements Exception {
  const AppError({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

final class DatabaseMigrationError extends AppError {
  const DatabaseMigrationError({required super.message})
    : super(code: 'database_migration_failed');
}

final class LocalPersistenceError extends AppError {
  const LocalPersistenceError({required super.message})
    : super(code: 'local_persistence_failed');
}
