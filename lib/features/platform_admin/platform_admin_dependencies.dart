import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_api_client.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_repository.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_repository_interface.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/repositories/platform_admin_token_store.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/services/platform_admin_service.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/services/platform_admin_service_interface.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/platform_admin_config.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// Registers what the platform admin shell is made of, and nothing at all while
/// the build has the shell switched off, so that an ordinary build has no
/// platform admin object, request or stored value to speak of.
///
/// The repository is one for the app, because it holds the session; the
/// controller is made for each time the shell is opened.
void registerPlatformAdminDependencies(GetIt locator, {bool enabled = PlatformAdminConfig.enabled}) {
  if (!enabled) return;

  locator.registerLazySingleton<PlatformAdminTokenStore>(() => SecurePlatformAdminTokenStore());
  locator.registerLazySingleton<PlatformAdminApiClient>(
    () => PlatformAdminApiClient(
      baseUrl: AppConstants.baseUrl,
      languageCode: () => locator<SharedPreferences>().getString(AppConstants.languageCode) ?? 'en',
    ),
  );
  locator.registerLazySingleton<PlatformAdminRepositoryInterface>(
    () => PlatformAdminRepository(apiClient: locator(), tokenStore: locator()),
  );
  locator.registerLazySingleton<PlatformAdminServiceInterface>(
    () => PlatformAdminService(platformAdminRepoInterface: locator()),
  );
  locator.registerFactory<PlatformAdminController>(
      () => PlatformAdminController(platformAdminServiceInterface: locator()));
}
