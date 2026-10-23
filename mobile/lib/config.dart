// MILO Runtime Config 
class MiloConfig {
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
 defaultValue: 'app.milo.milo_mobile',
 );

 static const String playStoreUrl =
 'https://play.google.com/store/apps/details?id=$androidPackage';

 static String deepLink(String shortCode) => 'milo://m/$shortCode';
 static String inviteLink(String shortCode) => '$webBaseUrl/m/$shortCode';

 static String eventLink(String eventId, {String? ref}) =>
 ref == null || ref.isEmpty
 ? '$webBaseUrl/e/$eventId'
 : '$webBaseUrl/e/$eventId?ref=$ref';

 static String passLink(String bookingId) => '$webBaseUrl/pass/$bookingId';

 static String promoterLink() => '$webBaseUrl/promoter';
}
