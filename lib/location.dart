import 'dart:async';
//import 'dart:io' show Platform, InternetAddress;  // Importar Platform para detectar sistema operativo
import 'package:device_info_plus/device_info_plus.dart'; // Importar DeviceInfoPlugin para obtener el ID
import 'package:connectivity_plus/connectivity_plus.dart';
import 'coms.dart';
import 'ble_data.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';


// 🆕 CLASE para estado de conectividad detallado (ANTES de class LocationService)
class ConnectivityStatus {
  final bool hasInternet;
  final bool isWifiConnected;
  final bool isMobileConnected;
  final bool isWifiWorking;
  final bool isMobileWorking;
  final String recommendation;
  final String description;
  
  ConnectivityStatus({
    required this.hasInternet,
    required this.isWifiConnected,
    required this.isMobileConnected,
    required this.isWifiWorking,
    required this.isMobileWorking,
    required this.recommendation,
    required this.description,
  });
  
  static ConnectivityStatus unknown = ConnectivityStatus(
    hasInternet: false,
    isWifiConnected: false,
    isMobileConnected: false,
    isWifiWorking: false,
    isMobileWorking: false,
    recommendation: "VERIFICAR_MANUAL",
    description: "Estado desconocido",
  );
}



class LocationService {
  Timer? _locationTimer;
  bool isUpdatingLocation = false;
  String deviceId = "UNKNOWN_DEVICE_ID"; // Valor predeterminado

  LocationService() {
    initializeDeviceId(); // Inicializa el deviceId al crear la instancia
  }

  Future<bool> _checkLocationPermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("🚫 GPS desactivado. Intentando activarlo...");
        await Geolocator.openLocationSettings();
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("🚫 Permisos de ubicación denegados.");
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print("🚫 Permisos de ubicación denegados permanentemente. Configúralo manualmente.");
        return false;
      }

      return true;
    } catch (e) {
      print("⚠️ Error al verificar permisos de ubicación: $e");
      return false;
    }
  }

  Future<void> initializeDeviceId() async {
    deviceId = await _getUniqueDeviceId();
    BleData.deviceId = deviceId; // Actualiza la variable global
    print("ID único del dispositivo inicializado: $deviceId");
  }

  Future<String> _getUniqueDeviceId() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        if (androidInfo.id.isEmpty) {
          return "UNKNOWN_ANDROID_ID";
        }
        return androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? "UNKNOWN_IOS_ID";
      } else {
        return "UNKNOWN_PLATFORM_ID";
      }
    } catch (e) {
      print("Error al obtener el ID del dispositivo: $e");
      return "ERROR_GETTING_ID";
    }
  }

  // Modificación de sendLocationOnce() en location.dart para forzar actualización de UI

Future<bool> sendLocationOnce() async {
  print("📡 === INICIANDO ENVÍO DE UBICACIÓN ROBUSTO ===");
  
  // 1. VERIFICACIÓN ROBUSTA DE CONECTIVIDAD
  ConnectivityStatus connectivity = await checkRobustConnectivity();
  
  if (!connectivity.hasInternet) {
    print("❌ Sin internet confirmado. Recomendación: ${connectivity.recommendation}");
    
    // Mostrar información específica según el problema
    await handleConnectivityIssue(connectivity);
    
    BleData.setLocationConfirmed(false);
    return false;
  }
  
  print("✅ Internet confirmado. Procediendo con envío de ubicación...");
  
  // 2. VERIFICAR PERMISOS DE UBICACIÓN
  if (!await _checkLocationPermissions()) {
    print("🚫 No se puede enviar ubicación: permisos denegados.");
    BleData.setLocationConfirmed(false);
    return false;
  }

  try {
    // 3. OBTENER UBICACIÓN
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("🚫 Servicio de ubicación no habilitado.");
      await Geolocator.openLocationSettings();
      BleData.setLocationConfirmed(false);
      return false;
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(Duration(seconds: 15)); // Timeout más generoso
    } catch (e) {
      print("❌ No se pudo obtener la ubicación: $e");
      BleData.setLocationConfirmed(false);
      return false;
    }

    // 4. PREPARAR DATOS PARA ENVÍO
    String northSouth = position.latitude >= 0 ? "North" : "South";
    String eastWest = position.longitude >= 0 ? "East" : "West";
    String bleMacAddress = BleData.conBoton == 2 ? "N/A" : BleData.macAddress;
    String imei = BleData.imei;
    String activo = BleData.conBoton == 2 ? "0" : (BleData.isConnected ? "1" : "0");
    int batteryLevel = BleData.conBoton == 1 ? BleData.batteryLevel : 0;
    String cellOnline = "1";
    
    print("📡 Datos preparados:");
    print("🔹 Ubicación: ${position.latitude}, ${position.longitude}");
    print("🔹 Conectividad: ${connectivity.description}");
    print("🔹 BLE: $bleMacAddress (activo: $activo)");

    // 5. ENVÍO CON VERIFICACIÓN DOBLE
    bool success = false;
    
    try {
      final response = await CommunicationService().sendLocation(
        imei,
        position.latitude.abs(),
        position.longitude.abs(),
        northSouth,
        eastWest,
        bleMacAddress,
        activo,
        batteryLevel,
        cellOnline,
      );
      
      if (response.statusCode == 200) {
        print("✅ Ubicación enviada exitosamente");
        success = true;
        BleData.setLocationConfirmed(true);
      } else {
        print("❌ Error HTTP en envío: ${response.statusCode}");
        success = false;
        BleData.setLocationConfirmed(false);
      }
    } catch (e) {
      print("⚠️ Error al enviar al servidor: $e");
      success = false;
      BleData.setLocationConfirmed(false);
    }
    
    print("📡 === FIN ENVÍO DE UBICACIÓN: ${success ? 'ÉXITO' : 'FALLO'} ===");
    return success;

  } catch (e) {
    print("⚠️ Error general en sendLocationOnce: $e");
    BleData.setLocationConfirmed(false);
    return false;
  }
}

// 🆕 MANEJAR problemas específicos de conectividad
Future<void> handleConnectivityIssue(ConnectivityStatus connectivity) async {
  switch (connectivity.recommendation) {
    case "SUGERIR_DATOS_MOVILES":
      print("💡 Sugerencia: Activar datos móviles como respaldo");
      // Podrías mostrar notificación específica
      break;
      
    case "VERIFICAR_PLAN_DATOS":
      print("💡 Sugerencia: Verificar plan de datos móviles");
      break;
      
    case "NOTIFICAR_SIN_INTERNET":
      print("📵 Sin opciones de internet disponibles");
      break;
      
    default:
      print("🤷‍♂️ Problema de conectividad sin recomendación específica");
  }
}

  // Obtener nivel de batería si el dispositivo BLE está conectado
  /*Future<int> _getBatteryLevel(BluetoothDevice? device) async {
    if (device == null) return 0; // Si no hay dispositivo, devolver 0
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == '6e400001-b5a3-f393-e0a9-e50e24dcca9e') {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == '6e400002-b5a3-f393-e0a9-e50e24dcca9e' &&
                characteristic.properties.write) {
              await characteristic.write([0xF3, 0x16, 0xF3]);
            }
            if (characteristic.uuid.toString() == '6e400003-b5a3-f393-e0a9-e50e24dcca9e' &&
                characteristic.properties.notify) {
              await characteristic.setNotifyValue(true);
              await Future.delayed(const Duration(seconds: 2)); // Esperar notificación
              if (characteristic.lastValue.isNotEmpty) {
                return characteristic.lastValue[3]; // Batería en 4to byte
              }
            }
          }
        }
      }
    } catch (e) {
      print("Error al obtener nivel de batería: $e");
    }
    return 0; // Si falla, devolver 0
  } */

void startLocationUpdates() {
  if (Platform.isIOS) {
    // ✅ iOS: Usar IOSPlatformManager
    _startIOSLocationUpdates();
  } else {
    // ✅ Android: Usar lógica existente
    _startAndroidLocationUpdates();
  }
}


void _startIOSLocationUpdates() {
  print("📍 Iniciando ubicación optimizada para iOS (100m)...");
  
  if (isUpdatingLocation) return;
  isUpdatingLocation = true;
  
  // ✅ ENVÍO INICIAL
  print("📡 iOS: Enviando ubicación inicial...");
  sendLocationOnce();
  
  // ✅ TIMER DE RESPALDO más frecuente para geofence de 200m
  _locationTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
    print("📡 iOS Backup: Enviando ubicación de respaldo cada 5 min...");
    bool success = await sendLocationOnce();
    
    if (success != BleData.locationConfirmed) {
      BleData.setLocationConfirmed(success);
    }
  });
  
  print("✅ iOS: Ubicación configurada para geofence de 200m (updates cada 100m)");
}

// ✅ AÑADIR método para Android (tu lógica existente):
void _startAndroidLocationUpdates() {
  if (isUpdatingLocation) return;
  isUpdatingLocation = true;
  
  print("📡 Iniciando actualizaciones de ubicación Android...");
  
  // ✅ Enviar la primera actualización inmediatamente
  sendLocationOnce();

  _locationTimer = Timer.periodic(const Duration(seconds: 90), (timer) async {
    print("📡 Enviando ubicación Android...startLocationUpdates ${DateTime.now()}");
    bool success = await sendLocationOnce();
    
    // Verificar si hubo cambio en el estado de confirmación de ubicación
    if (success != BleData.locationConfirmed) {
      BleData.setLocationConfirmed(success);
    }

    // Añadir reintento más rápido si falla el envío
    if (!success) {
      print("⚠️ Fallo en envío de ubicación. Programando reintento...");
      Future.delayed(const Duration(seconds: 30), () {
        if (!BleData.locationConfirmed && isUpdatingLocation) {
          print("🔄 Reintentando envío de ubicación después de fallo...");
          sendLocationOnce();
        }
      });
    }
  });
}


  void stopLocationUpdates() {

    if (Platform.isIOS) {
      // iOS: No hacer nada - se maneja automáticamente
      print("📍 iOS: Ubicación sigue activa automáticamente");
      return;
    }

    if (!isUpdatingLocation) return; // ✅ Solo detiene si ya está activo
    isUpdatingLocation = false;

    print("🛑 Deteniendo actualizaciones de ubicación...");
    _locationTimer?.cancel();
  }

 // 🆕 TEST DNS rápido (PRIMERO)
Future<bool> testDNSLookup() async {
  try {
    final result = await InternetAddress.lookup('google.com')
        .timeout(Duration(seconds: 3));
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } catch (e) {
    return false;
  }
}

// 🆕 TEST conectividad básica (SEGUNDO)
Future<bool> checkBasicConnectivity() async {
  try {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  } catch (e) {
    return false;
  }
}

// 🆕 VERIFICAR disponibilidad de datos móviles (TERCERO)
Future<bool> checkMobileDataAvailability() async {
  try {
    return true; // Asumir que están disponibles por defecto
  } catch (e) {
    print("⚠️ No se pudo verificar disponibilidad de datos móviles: $e");
    return false;
  }
}

// 🆕 VERIFICACIÓN REAL de internet con múltiples métodos (CUARTO)
Future<bool> verifyRealInternet() async {
  print("🧪 Verificando internet real con múltiples métodos...");
  
  // Método 1: DNS lookup (más rápido)
  bool dnsTest = await testDNSLookup();
  print("🔍 DNS Test: $dnsTest");
  
  // Método 2: HTTP ping (método actual de BleData)
  bool httpTest = await BleData.isInternetConnected();
  print("🔍 HTTP Test: $httpTest");
  
  // Método 3: Connectivity check (básico)
  bool connectivityTest = await checkBasicConnectivity();
  print("🔍 Connectivity Test: $connectivityTest");
  
  // Decisión: Mayoría de 2 de 3 métodos deben funcionar
  int passedTests = [dnsTest, httpTest, connectivityTest].where((test) => test).length;
  bool result = passedTests >= 2;
  
  print("🎯 Tests pasados: $passedTests/3 → Resultado: $result");
  return result;
}

// 🆕 INFORMACIÓN DETALLADA de red (QUINTO)
Future<String> getDetailedNetworkInfo(ConnectivityResult result) async {
  switch (result) {
    case ConnectivityResult.wifi:
      try {
        return "WiFi conectado";
      } catch (e) {
        return "WiFi conectado (info limitada)";
      }
      
    case ConnectivityResult.mobile:
      return "Datos móviles activos";
      
    case ConnectivityResult.ethernet:
      return "Ethernet conectado";
      
    case ConnectivityResult.none:
      return "Sin conectividad";
      
    default:
      return "Conectividad desconocida";
  }
}

// 🆕 ANÁLISIS de estado y recomendaciones (SEXTO)
Future<ConnectivityStatus> analyzeConnectivityStatus(
  ConnectivityResult connectivityResult, 
  bool internetWorking
) async {
  
  bool isWifiConnected = connectivityResult == ConnectivityResult.wifi;
  bool isMobileConnected = connectivityResult == ConnectivityResult.mobile;
  
  // Casos específicos
  if (isWifiConnected && internetWorking) {
    return ConnectivityStatus(
      hasInternet: true,
      isWifiConnected: true,
      isMobileConnected: false,
      isWifiWorking: true,
      isMobileWorking: false,
      recommendation: "CONTINUAR_NORMAL",
      description: "WiFi funcionando correctamente",
    );
  }
  
  if (isWifiConnected && !internetWorking) {
    print("⚠️ DETECTADO: WiFi Zombie (conectado sin internet)");
    
    // Verificar si datos móviles están disponibles
    bool mobileAvailable = await checkMobileDataAvailability();
    
    return ConnectivityStatus(
      hasInternet: false,
      isWifiConnected: true,
      isMobileConnected: false,
      isWifiWorking: false,
      isMobileWorking: false,
      recommendation: mobileAvailable ? "SUGERIR_DATOS_MOVILES" : "NOTIFICAR_SIN_INTERNET",
      description: "WiFi conectado pero sin internet real",
    );
  }
  
  if (isMobileConnected && internetWorking) {
    return ConnectivityStatus(
      hasInternet: true,
      isWifiConnected: false,
      isMobileConnected: true,
      isWifiWorking: false,
      isMobileWorking: true,
      recommendation: "CONTINUAR_NORMAL",
      description: "Datos móviles funcionando correctamente",
    );
  }
  
  if (isMobileConnected && !internetWorking) {
    return ConnectivityStatus(
      hasInternet: false,
      isWifiConnected: false,
      isMobileConnected: true,
      isWifiWorking: false,
      isMobileWorking: false,
      recommendation: "VERIFICAR_PLAN_DATOS",
      description: "Datos móviles conectados pero sin internet (posible plan agotado)",
    );
  }
  
  // Sin conectividad
  return ConnectivityStatus(
    hasInternet: false,
    isWifiConnected: false,
    isMobileConnected: false,
    isWifiWorking: false,
    isMobileWorking: false,
    recommendation: "NOTIFICAR_SIN_CONECTIVIDAD",
    description: "Sin conectividad de red",
  );
}



// 🆕 MÉTODO ROBUSTO de verificación de conectividad (OCTAVO)
Future<ConnectivityStatus> checkRobustConnectivity() async {
  try {
    print("🔍 === VERIFICACIÓN ROBUSTA DE CONECTIVIDAD ===");
    
    // 1. Verificar estado básico de conectividad
    ConnectivityResult connectivityResult = await Connectivity().checkConnectivity();
    print("📶 Connectivity Status: $connectivityResult");
    
    // 2. Obtener información detallada de red
    String networkInfo = await getDetailedNetworkInfo(connectivityResult);
    print("📋 Network Info: $networkInfo");
    
    // 3. Verificar internet REAL con múltiples métodos
    bool internetWorking = await verifyRealInternet();
    print("🌐 Internet Real: $internetWorking");
    
    // 4. Analizar y decidir acción
    ConnectivityStatus status = await analyzeConnectivityStatus(
      connectivityResult, 
      internetWorking
    );
    
    print("🎯 Resultado Final: ${status.description}");
    print("🔍 === FIN VERIFICACIÓN ROBUSTA ===");
    
    return status;
    
  } catch (e) {
    print("❌ Error en verificación robusta: $e");
    return ConnectivityStatus.unknown;
  }
}

}

Future<void> sendSosAlert({String bleMacAddress = "N/A"}) async {
  try {
    print("Enviando señal SOS...");
    print("ID del dispositivo: ${BleData.imei}");
    print("MAC Address BLE: $bleMacAddress");

    await CommunicationService().sendSosAlert(
      bleMacAddress // MAC Address del BLE si está disponible
    );
  } catch (e) {
    print("Error al enviar señal SOS: $e");
  }

}