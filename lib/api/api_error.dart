import '../core/l10n.dart';

enum ApiErrorKind {
  unauthorized,
  forbidden,
  notFound,
  repoPasswordRequired,
  twoFactorRequired,
  invalidCredentials,
  invalidOtp,
  network,
  server,
  cancelled,
  decoding,
  unknown,
}

class ApiException implements Exception {
  ApiException(this.kind, {this.status, this.serverMessage});

  final ApiErrorKind kind;
  final int? status;
  final String? serverMessage;

  bool get isUnauthorized => kind == ApiErrorKind.unauthorized;

  String friendly(L10n l10n) {
    final message = serverMessage?.trim();
    switch (kind) {
      case ApiErrorKind.unauthorized:
        return l10n.sessionExpired;
      case ApiErrorKind.forbidden:
        return l10n.permissionDenied;
      case ApiErrorKind.notFound:
        return l10n.notFound;
      case ApiErrorKind.repoPasswordRequired:
        return l10n.unlockRequired;
      case ApiErrorKind.twoFactorRequired:
        return l10n.twoFactorTitle;
      case ApiErrorKind.invalidCredentials:
        return l10n.wrongCredentials;
      case ApiErrorKind.invalidOtp:
        return l10n.invalidOtp;
      case ApiErrorKind.network:
        return l10n.networkError;
      case ApiErrorKind.server:
        return message?.isNotEmpty == true ? message! : l10n.serverError;
      case ApiErrorKind.cancelled:
        return l10n.cancelled;
      case ApiErrorKind.decoding:
        return l10n.unknownError;
      case ApiErrorKind.unknown:
        return message?.isNotEmpty == true ? message! : l10n.unknownError;
    }
  }

  @override
  String toString() => 'ApiException($kind, status: $status, message: $serverMessage)';
}

class RepoCryptoException implements Exception {
  const RepoCryptoException(this.message, {this.wrongPassword = false});

  final String message;
  final bool wrongPassword;

  @override
  String toString() => message;
}
