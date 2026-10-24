// JHOOMO Runtime Config 
class JhoomoConfig {
  static const MiloConfig = JhoomoConfig();
  const JhoomoConfig();

  // Backward compatibility
  static const String apiBaseUrl = String.fromEnvironment(
    'MILO_API_URL',
    defaultValue: 'https://milo-sandy-three.vercel.app',
  );
  static const String webBaseUrl = String.fromEnvironment(
    'MILO_WEB_URL',
    defaultValue: 'https://milo-sandy-three.vercel.app',
  );
  static const String androidPackage = String.fromEnvironment(
    'MILO_ANDROID_PACKAGE',
    defaultValue: 'app.jhoomo.jhoomo_mobile',
  );

  static String get playStoreUrl =>
      'https://play.google.com/store/apps/details?id=$androidPackage';

  static String deepLink(String shortCode) => 'jhoomo://m/$shortCode';
  static String inviteLink(String shortCode) => '$webBaseUrl/m/$shortCode';

  static String eventLink(String eventId, {String? ref}) =>
      ref == null || ref.isEmpty
          ? '$webBaseUrl/e/$eventId'
          : '$webBaseUrl/e/$eventId?ref=$ref';

  static String passLink(String bookingId) => '$webBaseUrl/pass/$bookingId';

  static String promoterLink() => '$webBaseUrl/promoter';
}

typedef MiloConfig = JhoomoConfig;
