import 'dart:async';
import 'dart:io';
import 'foreground.dart' as android_foreground;
// import 'ios_platform_manager.dart'; // ✅ Descomentar cuando esté listo

class PlatformManager {
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  
  // ✅ INICIALIZACIÓN UNIFICADA
  static Future<void> initialize() async {
    if (isAndroid) {
      // Usar implementación Android existente
      await android_foreground.ForegroundService.initForegroundTask();
    } else if (isIOS) {
      // Usar nueva implementación iOS (cuando esté lista)
      // await IOSPlatformManager.initialize();
      print("🍎 iOS: Inicialización básica (IOSPlatformManager pendiente)");
    }
  }
  
  // ✅ INICIAR SERVICIO SEGÚN PLATAFORMA
  static Future<void> startService() async {
    if (isAndroid) {
      await android_foreground.ForegroundService.startForegroundTask();
    } else if (isIOS) {
      // iOS no necesita "servicio" - todo es automático
      print("✅ iOS: Servicios background configurados automáticamente");
    }
  }
  
  // ✅ DETENER SERVICIO SEGÚN PLATAFORMA  
  static Future<void> stopService() async {
    if (isAndroid) {
      // ✅ USAR MÉTODO QUE SÍ EXISTE
      android_foreground.ForegroundService.stopForegroundTask();
    } else if (isIOS) {
      // await IOSPlatformManager.dispose();
      print("🍎 iOS: Recursos limpiados automáticamente");
    }
  }
  
  // ✅ VERIFICAR ESTADO DEL SERVICIO
  static Future<bool> isServiceRunning() async {
    if (isAndroid) {
      return android_foreground.ForegroundService.isRunning;
    } else if (isIOS) {
      // return IOSPlatformManager.isLocationActive;
      return true; // Temporalmente hasta que IOSPlatformManager esté listo
    }
    return false;
  }
  
  // ✅ REGISTRAR CALLBACK DE UBICACIÓN
  static void registerLocationCallback(Function callback) {
    if (isAndroid) {
      android_foreground.ForegroundService.registerLocationServiceCallback(callback);
    }
    // iOS no necesita callback manual - es automático
  }
}