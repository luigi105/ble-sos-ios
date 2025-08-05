import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:async';
import 'dart:io'; // ✅ CRÍTICO para Platform.isIOS
import 'foreground.dart';
import 'connect.dart';
import 'location.dart';
import 'ble_data.dart';
import 'coms.dart';
import 'start_page.dart';
import 'settings_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'permission_guide.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ✅ IMPORT PARA iOS (descomentar cuando esté listo)
import 'ios_permission_guide.dart';
import 'ios_platform_manager.dart';
import 'connect.dart' as connect_helper;

bool isRequestingPermissions = false;
bool batteryPermissionAlreadyRequested = false;
LocationService locationService = LocationService();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  print("🚀 Flutter Engine iniciado en main()");
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ INICIALIZACIÓN ESPECÍFICA POR PLATAFORMA
  if (Platform.isIOS) {
    print("🍎 Detectado iOS - Configuración básica por ahora");
    await IOSPlatformManager.initialize();
  } else {
    print("🤖 Detectado Android - Usando estrategia Android existente");
  }

  // 🔍 DEBUG ANTES de cargar
  print("🔍 conBoton ANTES de cargar: ${BleData.conBoton}");
  print("🔍 imei ANTES de cargar: ${BleData.imei}");

  // 🔧 LIMPIEZA INICIAL: Verificar y detener cualquier servicio anterior
  try {
    bool wasServiceRunning = await FlutterForegroundTask.isRunningService;
    if (wasServiceRunning) {
      print("⚠️ Detectado servicio anterior ejecutándose. Deteniéndolo...");
      await FlutterForegroundTask.stopService();
      print("✅ Servicio anterior detenido");
    }
  } catch (e) {
    print("ℹ️ No se detectó servicio anterior o error al verificar: $e");
  }

  // ✅ NUEVA VERIFICACIÓN: Detectar instalación nueva y limpiar automáticamente
  await BleData.checkFirstInstallAndCleanIfNeeded();

  // ✅ CARGAR DATOS PRIMERO, ANTES DE SOLICITAR PERMISOS
  await BleData.loadConBoton();
  await BleData.loadMacAddress();
  await BleData.loadImei();
  
  // 🔍 DEBUG DESPUÉS de cargar  
  print("🔍 conBoton DESPUÉS de cargar: ${BleData.conBoton}");
  print("🔍 imei DESPUÉS de cargar: ${BleData.imei}");
  
  await BleData.loadSosNumber(); 
  await BleData.loadAutoCall();
  await BleData.loadSosNotificationEnabled();
  await BleData.loadBleNotificationsEnabled();
  await BleData.loadConnectionNotificationsEnabled(); 
  
  // ✅ SOLICITAR PERMISOS DESPUÉS DE CARGAR DATOS
  await requestPermissions();
  await checkLocationPermissions();

  // 🔍 VERIFICAR después de cargar
  print("🔍 Estado de configuración inicial DESPUÉS de cargar:");
  print("   - conBoton: ${BleData.conBoton}");
  print("   - IMEI: ${BleData.imei}");
  print("   - MacAddress: ${BleData.macAddress}");
  print("   - sosNumber: ${BleData.sosNumber}");
  print("   - Plataforma: ${Platform.isIOS ? 'iOS' : 'Android'}");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: BleData.conBoton == 0
          ? const StartPage()
          : const BleScanPage(),
    );
  }
}

class BleScanPage extends StatefulWidget {
  const BleScanPage({super.key});

  @override
  BleScanPageState createState() => BleScanPageState();
}


Future<void> requestPermissions() async {
  if (isRequestingPermissions) {
    print("⚠️ Ya se están solicitando permisos, evitando duplicación");
    return;
  }
  
  isRequestingPermissions = true; 
  print("⚠️ Verificando permisos para ${Platform.isIOS ? 'iOS' : 'Android'}...");

  try {
    if (Platform.isAndroid) {
      // ✅ ANDROID: Lógica existente (sin cambios)
      List<Permission> permissionsToRequest = [
        Permission.locationAlways,
        Permission.location,
        Permission.notification,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.phone,
      ];
      
      Map<Permission, PermissionStatus> statuses = await permissionsToRequest.request();
      
      print("🔍 Estado de permisos Android:");
      statuses.forEach((permiso, estado) {
        String emoji = estado.isGranted ? "✅" : "❌";
        print("$emoji $permiso -> $estado");
      });
      
    } else if (Platform.isIOS) {
      // ✅ iOS: VERIFICAR PRIMERO - NO SOLICITAR EN CADA INICIO
      print("🍎 === VERIFICACIÓN ÚNICA DE PERMISOS iOS ===");
      
      // Verificar estado actual
      bool locationAlwaysGranted = await Permission.locationAlways.isGranted;
      bool bluetoothGranted = await Permission.bluetooth.isGranted;
      bool notificationGranted = await Permission.notification.isGranted;
      
      print("📊 Estado actual iOS:");
      print("📍 Ubicación siempre: ${locationAlwaysGranted ? '✅' : '❌'}");
      print("🔵 Bluetooth: ${bluetoothGranted ? '✅' : '❌'}");
      print("🔔 Notificaciones: ${notificationGranted ? '✅' : '❌'}");
      
      // ✅ SOLO SOLICITAR SI REALMENTE FALTAN
      bool needsLocationPermission = !locationAlwaysGranted;
      bool needsBluetoothPermission = !bluetoothGranted;
      bool needsNotificationPermission = !notificationGranted;
      
      if (needsLocationPermission || needsBluetoothPermission || needsNotificationPermission) {
        print("⚠️ Faltan permisos - Dirigir a pantalla de configuración");
        // NO solicitar aquí - dejar que IOSPermissionGuidePage lo haga
      } else {
        print("✅ Todos los permisos iOS ya están configurados - No solicitar nada");
      }
    }
    
    // ✅ SOLICITAR PERMISOS DE BATERÍA SOLO EN ANDROID
    if (Platform.isAndroid && !batteryPermissionAlreadyRequested) {
      print("🔋 Solicitando permisos de batería para Android...");
      await requestBatteryOptimizationsIfNeeded();
    }
    
  } catch (e) {
    print("❌ Error durante verificación de permisos: $e");
  }

  await Future.delayed(const Duration(seconds: 1)); 
  isRequestingPermissions = false;
  print("✅ Verificación de permisos completada para ${Platform.isIOS ? 'iOS' : 'Android'}.");

  // ✅ VERIFICAR GPS AL FINAL (solo si no está activado)
  bool gpsEnabled = await Geolocator.isLocationServiceEnabled();
  if (!gpsEnabled) {
    print("⚠️ GPS desactivado - NO abrir Settings automáticamente");
    print("ℹ️ El usuario puede activar GPS desde la pantalla de permisos");
  }
}

Future<void> checkPermissionsStatusOnly() async {
  print("🔍 === VERIFICACIÓN DE ESTADO (sin solicitar) ===");
  
  if (Platform.isIOS) {
    bool locationAlways = await Permission.locationAlways.isGranted;
    bool bluetooth = await Permission.bluetooth.isGranted;
    bool notification = await Permission.notification.isGranted;
    
    print("📊 Estado iOS:");
    print("   📍 Ubicación siempre: ${locationAlways ? '✅' : '❌'}");
    print("   🔵 Bluetooth: ${bluetooth ? '✅' : '❌'}");
    print("   🔔 Notificaciones: ${notification ? '✅' : '❌'}");
    
    if (locationAlways && bluetooth && notification) {
      print("✅ Todos los permisos iOS están configurados");
    } else {
      print("⚠️ Faltan algunos permisos iOS");
    }
  }
  
  print("🔍 === FIN VERIFICACIÓN ===");
}

Future<void> verifyPermissionsAfterStartup() async {
  print("🔍 VERIFICACIÓN FINAL de permisos después del inicio:");
  
  Map<Permission, PermissionStatus> currentStatuses = {};
  
  List<Permission> allPermissions = Platform.isAndroid ? [
    Permission.locationAlways,
    Permission.location,
    Permission.notification,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.phone,
  ] : [
    Permission.locationAlways,
    Permission.locationWhenInUse,
    Permission.notification,
    Permission.bluetooth,
  ];
  
  for (Permission permission in allPermissions) {
    currentStatuses[permission] = await permission.status;
  }
  
  currentStatuses.forEach((permiso, estado) {
    String emoji = estado.isGranted ? "✅" : "❌";
    print("$emoji FINAL: $permiso -> $estado");
  });
  
  // Verificar específicamente los críticos para la funcionalidad
  bool locationOK = await Permission.location.isGranted;
  bool locationAlwaysOK = await Permission.locationAlways.isGranted;
  bool notificationOK = await Permission.notification.isGranted;
  
  print("📊 RESUMEN FUNCIONAL:");
  print("   📍 Ubicación básica: ${locationOK ? 'OK' : 'FALTA'}");
  print("   📍 Ubicación siempre: ${locationAlwaysOK ? 'OK' : 'FALTA'}");
  print("   🔔 Notificaciones: ${notificationOK ? 'OK' : 'FALTA'}");
  
  if (Platform.isAndroid) {
    bool bleOK = await Permission.bluetoothScan.isGranted && await Permission.bluetoothConnect.isGranted;
    bool phoneOK = await Permission.phone.isGranted;
    print("   🔵 Bluetooth: ${bleOK ? 'OK' : 'FALTA'}");
    print("   📞 Llamadas: ${phoneOK ? 'OK' : 'FALTA'}");
  } else {
    bool bleOK = await Permission.bluetooth.isGranted;
    print("   🔵 Bluetooth: ${bleOK ? 'OK' : 'FALTA'}");
  }
}

// Función de optimizaciones de batería solo para Android
Future<bool> requestBatteryOptimizationsIfNeeded() async {
  if (Platform.isIOS) {
    print("ℹ️ iOS no necesita optimizaciones de batería manuales");
    return true;
  }
  
  print("🔋 Verificando si necesitamos permisos de batería en Android...");
  
  if (batteryPermissionAlreadyRequested) {
    print("✅ Permisos de batería ya fueron solicitados en esta sesión");
    return await Permission.ignoreBatteryOptimizations.isGranted;
  }
  
  bool alreadyGranted = await Permission.ignoreBatteryOptimizations.isGranted;
  
  if (alreadyGranted) {
    print("✅ Ya tenemos permisos de optimización de batería");
    batteryPermissionAlreadyRequested = true;
    return true;
  }
  
  print("📱 Solicitando permisos de optimización de batería...");
  batteryPermissionAlreadyRequested = true;
  
  PermissionStatus result = await Permission.ignoreBatteryOptimizations.request();
  
  if (result.isGranted) {
    print("✅ Permisos de batería concedidos");
    return true;
  } else {
    print("❌ Permisos de batería denegados");
    return false;
  }
}

Future<void> checkLocationPermissions() async {
  bool gpsEnabled = await Geolocator.isLocationServiceEnabled();
  if (!gpsEnabled) {
    print("⚠️ GPS desactivado, solicitando activación...");
    await Geolocator.openLocationSettings();
    return;
  }

  LocationPermission permission = await Geolocator.checkPermission();
  
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    print("⚠️ Permisos de ubicación no otorgados. Ya se solicitaron en requestPermissions()");
  } else {
    print("✅ Permisos de ubicación ya están otorgados");
  }
}

class BleScanPageState extends State<BleScanPage> with WidgetsBindingObserver {
  List<ScanResult> scanResults = [];
  bool buttonPressed = false;
  bool isForegroundServiceRunning = false;
  bool isScanning = false;
  Timer? panicTimer;
  Timer? locationTimer;
  Timer? updateTimer;
  Timer? retryScanTimer;
  Timer? sosTimer;
  bool _isMounted = false;
  bool isSosPressed = false;
  bool isSosActivated = false;
  Color sosButtonColor = Colors.grey;
  String sosButtonText = "Alerta SOS";
  LocationService locationService = LocationService();
  bool isAppInBackground = false;
  bool isReconnecting = false;
  Timer? backgroundReconnectionTimer;
  bool previousConnectionState = false;
  bool previousLocationConfirmed = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  ConnectivityResult _lastConnectivityResult = ConnectivityResult.none;
  Timer? _inactiveTimer;
  bool _appClosingPermanently = false;
  static const MethodChannel _lifecycleChannel = MethodChannel('com.miempresa.ble_sos_ap/lifecycle');
  Timer? _heartbeatTimer;
  int _heartbeatCount = 0;
  String _bluetoothState = "Verificando...";

  /*
  // ✅ VARIABLES DE DEBUG CONSOLIDADAS (sin duplicaciones)
  int _scanAttempts = 0;
  int _devicesFound = 0;
  int _holyIotFound = 0;
  String _lastScanStatus = "Sin escanear";
  List<String> _foundDeviceNames = [];
  List<String> _foundDeviceMacs = [];
  bool _targetDeviceFound = false;
  String _scanDetails = "Esperando...";
  
  // ✅ VARIABLES DE DEBUG DE SERVICIOS
  int _totalServices = 0;
  bool _sosServiceFound = false;
  bool _writeCharFound = false;
  bool _notifyCharFound = false;
  List<String> _foundServiceUuids = [];
  String _discoveryStatus = "Sin descubrir";
  String _lastBleData = "Sin datos";
  String _buttonStatus = "Sin estado";
  int _dataPacketsReceived = 0;
  String _lastButtonAction = "Ninguna";
  String _configurationStatus = "Sin configurar";

    // ✅ NUEVAS VARIABLES PARA DEBUG DE NOTIFICACIONES
  String _notificationDebugStatus = "Sin inicializar";
  String _lastNotificationError = "Ninguno";
  String _notificationPermissionStatus = "Desconocido";
  int _notificationAttempts = 0;
  int _notificationSuccesses = 0;
  String _lastNotificationTest = "Sin probar";
  String _iosManagerStatus = "Sin inicializar";
  String _localNotificationStatus = "Sin verificar";
*/

   @override
  void initState() {
    super.initState();
    _isMounted = true;
    WidgetsBinding.instance.addObserver(this);

    // ✅ CONFIGURAR CALLBACK PARA DEBUG SOS
    connect_helper.setSosDebugCallback((String action, dynamic data) {
      if (!mounted) return;
      
      setState(() {
        switch (action) {
          case "discoveryStart":
            _discoveryStatus = data as String;
            break;
          case "servicesFound":
            Map<String, dynamic> info = data as Map<String, dynamic>;
            _totalServices = info['total'] as int;
            _foundServiceUuids = (info['uuids'] as List).cast<String>();
            _discoveryStatus = "Servicios encontrados: $_totalServices";
            break;
          case "sosServiceFound":
            _sosServiceFound = data as bool;
            break;
          case "writeCharFound":
            _writeCharFound = data as bool;
            break;
          case "notifyCharFound":
            _notifyCharFound = data as bool;
            break;
          case "configStatus":
            _configurationStatus = data as String;
            break;
          case "dataReceived":
            List<int> rawData = data as List<int>;
            _dataPacketsReceived++;
            _lastBleData = rawData.length > 5 
                ? "${rawData.take(5).join(',')}.." 
                : rawData.join(',');
            break;
          case "buttonPressed":
            _buttonStatus = "PRESIONADO";
            _lastButtonAction = "Presionado ${DateTime.now().toString().substring(11, 19)}";
            break;
          case "buttonReleased":
            _buttonStatus = "SOLTADO";
            _lastButtonAction = "Soltado ${DateTime.now().toString().substring(11, 19)}";
            break;
        }
      });
    });

    // ✅ ESTRATEGIA ESPECÍFICA POR PLATAFORMA
    if (Platform.isIOS) {
      _initializeiOS();
    } else {
      _initializeAndroid();
    }
  }

  
Future<void> _runDiagnostic() async {
  try {
    print("🔧 === USANDO FUNCIÓN ORIGINAL ===");
    
    // Mostrar que vamos a usar la función original
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🔧 Usando función original startScanAndConnect()..."),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
    
    await Future.delayed(Duration(seconds: 1));
    
    // 1. Verificar configuración básica
    if (BleData.conBoton != 1) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("❌ BLE DESHABILITADO"),
          content: Text("conBoton = ${BleData.conBoton}\n\nBLE no está habilitado. Ve a configuración y habilita BLE."),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))],
        ),
      );
      return;
    }
    
    // 2. Verificar Bluetooth
    BluetoothAdapterState adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("❌ BLUETOOTH APAGADO"),
          content: Text("Estado: $adapterState\n\nActiva Bluetooth y prueba de nuevo."),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))],
        ),
      );
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✅ Configuración OK - Usando función original..."),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    
    await Future.delayed(Duration(seconds: 2));
    
    // 3. ✅ USAR LA FUNCIÓN ORIGINAL QUE YA FUNCIONABA
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🔍 Ejecutando startScanAndConnect() original..."),
        backgroundColor: Colors.purple,
        duration: Duration(seconds: 4),
      ),
    );
    
    // ✅ LLAMAR A LA FUNCIÓN ORIGINAL
    bool success = await startScanAndConnect();
    
    await Future.delayed(Duration(seconds: 2));
    
    // 4. Mostrar resultado
    if (success) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("🎉 ¡ÉXITO!"),
          content: Text("La función original funcionó correctamente.\n\nDispositivo conectado: ${BleData.isConnected}\nUUID: ${BleData.macAddress}"),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("¡Genial!"))],
        ),
      );
      
      // Actualizar UI
      if (mounted) {
        setState(() {});
      }
      
    } else {
      // Si la función original también falla, el problema es más profundo
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("⚠️ FUNCIÓN ORIGINAL TAMBIÉN FALLA"),
          content: Text("Incluso la función original startScanAndConnect() que funcionaba antes ahora falla.\n\n¿Hiciste algún cambio en:\n- Info.plist\n- Permisos iOS\n- Configuración del proyecto?\n\nDispositivo conectado: ${BleData.isConnected}"),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("Revisar"))],
        ),
      );
    }
    
  } catch (e) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("❌ ERROR"),
        content: Text("Error ejecutando diagnóstico: $e"),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))],
      ),
    );
  }
}


// ✅ FUNCIÓN COMPLETA _initializeiOS() CORREGIDA para main.dart:

Future<void> _initializeiOS() async {
  print("🍎 Inicializando estrategia iOS...");
  
  // Inicializar estados anteriores
  previousConnectionState = BleData.isConnected;
  previousLocationConfirmed = BleData.locationConfirmed;

  locationService.initializeDeviceId().then((_) {
    print("Device ID inicializado correctamente: ${BleData.deviceId}");

    if (BleData.conBoton == 1) {
      // ✅ INICIALIZAR IOSPlatformManager PRIMERO
      IOSPlatformManager.initialize().then((_) {
        print("✅ IOSPlatformManager inicializado");

       // 🔔 MOSTRAR NOTIFICACIÓN PERSISTENTE después de inicializar
        
      Future.delayed(Duration(seconds: 4), () async {
        try {
          print("🔔 Llamada de respaldo: Creando notificación persistente...");
          await IOSPlatformManager.showPersistentMonitoringNotification();
          print("✅ Notificación persistente creada desde main.dart");
        } catch (e) {
          print("❌ Error en llamada de respaldo: $e");
        }
      });
        // Luego solicitar permisos
        requestPermissions().then((_) {
          Future.delayed(Duration(seconds: 3), () async {
            await verifyPermissionsAfterStartup();
            
            bool locationAlwaysGranted = await Permission.locationAlways.isGranted;
            
            if (!locationAlwaysGranted) {
              print("⚠️ Faltan permisos críticos, mostrando pantalla de configuración...");
              if (_isMounted && navigatorKey.currentContext != null) {
                Navigator.push(
                  navigatorKey.currentContext!,
                  MaterialPageRoute(builder: (context) => const IOSPermissionGuidePage()),
                );
              }
            } else {
              print("✅ Permisos iOS configurados correctamente");
              
              // ✅ NUEVO: Intentar conexión automática después de verificar permisos
              _attemptAutoConnection();
            }
          });
          
          // ✅ SIEMPRE iniciar ubicación
          if (!locationService.isUpdatingLocation) {
            print("📍 Iniciando servicio de ubicación iOS...");
            locationService.startLocationUpdates();
          }
        });
      });
    } else {
      // ✅ MODO 2: Solo ubicación GPS (sin cambios)
      IOSPlatformManager.initialize().then((_) {
        print("✅ IOSPlatformManager inicializado para modo GPS");
        
        requestPermissions().then((_) {
          Future.delayed(Duration(seconds: 3), () async {
            await verifyPermissionsAfterStartup();
            
            bool locationAlwaysGranted = await Permission.locationAlways.isGranted;
            
            if (!locationAlwaysGranted) {
              print("⚠️ Falta permiso de ubicación siempre, mostrando pantalla de configuración...");
              if (_isMounted && navigatorKey.currentContext != null) {
                Navigator.push(
                  navigatorKey.currentContext!,
                  MaterialPageRoute(builder: (context) => const IOSPermissionGuidePage()),
                );
              }
            } else {
              print("✅ Permisos iOS configurados correctamente para modo GPS");
            }
          });
          
          // ✅ SOLO iniciar ubicación (sin BLE)
          if (!locationService.isUpdatingLocation) {
            print("📍 Iniciando servicio de ubicación iOS (solo GPS)...");
            locationService.startLocationUpdates();
          }
        });
      });
    }
  });

  print("✅ iOS inicializado con IOSPlatformManager");
  
  // ✅ RESTO DEL CÓDIGO EXISTENTE (timers, etc.) sin cambios
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (_isMounted) {
      try {
        String permissionStatus = await IOSPlatformManager.checkCurrentPermissionStatus();
        setState(() {
          _notificationPermissionStatus = permissionStatus;
        });
      } catch (e) {
        print("Error actualizando permisos: $e");
      }
      
      try {
        BluetoothAdapterState bleState = await FlutterBluePlus.adapterState.first;
        _bluetoothState = bleState.toString().split('.').last;
      } catch (e) {
        _bluetoothState = "Error: $e";
      }
      
      setState(() {
        sosButtonColor = BleData.locationConfirmed ? Colors.green : Colors.grey;
        sosButtonText = BleData.locationConfirmed ? "Alerta SOS" : "Conectando...";
      });
    }
  });
  
  // ✅ TIMER DE RECOVERY para discovery (código existente sin cambios)
  Timer.periodic(Duration(seconds: 8), (timer) async {
    if (BleData.isConnected && _totalServices == 0 && BleData.conBoton == 1) {
      print("🔧 iOS: Servicios=0 pero conectado. Forzando discovery...");
      
      try {
        List<BluetoothDevice> devices = await FlutterBluePlus.connectedDevices;
        bool deviceFound = false;
        
        print("🔍 iOS: Verificando ${devices.length} dispositivos conectados...");
        
        for (var device in devices) {
          print("🔍 iOS: Dispositivo: '${device.platformName}' (${device.remoteId})");
          
          if (device.platformName.toLowerCase() == "holy-iot") {
            print("📍 iOS: ¡Encontrado Holy-IOT! Ejecutando discoverServices...");
            deviceFound = true;
            
            if (mounted) {
              setState(() {
                _discoveryStatus = "Forzando discovery manual...";
              });
            }
            
            discoverServices(device, context, activateSos);
            timer.cancel();
            print("✅ iOS: Timer de recovery cancelado - discovery ejecutado");
            break;
          }
        }
        
        if (!deviceFound) {
          print("⚠️ iOS: No se encontró Holy-IOT en ${devices.length} dispositivos conectados");
          if (mounted) {
            setState(() {
              _discoveryStatus = "Error: Holy-IOT no en ${devices.length} conectados";
            });
          }
        }
        
      } catch (error) {
        print("❌ iOS: Error obteniendo dispositivos conectados: $error");
        if (mounted) {
          setState(() {
            _discoveryStatus = "Error obteniendo dispositivos: $error";
          });
        }
      }
      
    } else if (_totalServices > 0) {
      if (timer.isActive) {
        print("✅ iOS: Servicios encontrados ($_totalServices), cancelando timer de recovery");
        timer.cancel();
      }
    } else if (BleData.conBoton != 1) {
      if (timer.isActive) {
        print("ℹ️ iOS: No está en modo BLE, cancelando timer de recovery");
        timer.cancel();
      }
    } else if (!BleData.isConnected) {
      if (mounted) {
        setState(() {
          _discoveryStatus = "Esperando conexión BLE...";
        });
      }
    }
  });
  
  print("✅ iOS inicializado con timer de recovery para discovery");
}



Future<void> _attemptAutoConnection() async {
  // Solo intentar si BLE está habilitado y no estamos ya conectados
  if (BleData.conBoton != 1 || BleData.isConnected) {
    print("🍎 iOS: No se requiere auto-conexión (conBoton=${BleData.conBoton}, conectado=${BleData.isConnected})");
    return;
  }
  
  print("🍎 === INICIANDO AUTO-CONEXIÓN iOS ===");
  
  try {
    // Verificar Bluetooth primero
    BluetoothAdapterState adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      print("🍎 Auto-conexión cancelada: Bluetooth apagado");
      return;
    }
    
    // Pequeña pausa para que iOS se estabilice
    await Future.delayed(Duration(seconds: 2));
    
    print("🍎 Ejecutando startScanAndConnect() automáticamente...");
    
    // ✅ Usar la función original que ya sabemos que funciona
    bool success = await startScanAndConnect();
    
    if (success) {
      print("🎉 iOS: Auto-conexión EXITOSA!");
      
      // Actualizar UI si está montada
      if (_isMounted) {
        setState(() {
          sosButtonColor = Colors.green;
          sosButtonText = "Alerta SOS";
        });
      }
      
      // Mostrar notificación de éxito (opcional)
      if (_isMounted && navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text("🎉 Dispositivo Holy-IOT conectado automáticamente"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
    } else {
      print("⚠️ iOS: Auto-conexión falló - el usuario puede usar el botón manual");
      
      // No mostrar error en auto-conexión, el usuario puede intentar manualmente
    }
    
  } catch (e) {
    print("❌ iOS: Error en auto-conexión: $e");
    // No mostrar error en pantalla para auto-conexión
  }
  
  print("🍎 === FIN AUTO-CONEXIÓN iOS ===");
}


Future<void> _debugNotificationSystemStepByStep() async {
  if (mounted) setState(() => _notificationDebugStatus = "Inicializando...");
  
  try {
    // ✅ SOLO verificar plataforma
    if (!Platform.isIOS) {
      if (mounted) setState(() => _notificationDebugStatus = "ERROR: No es iOS");
      return;
    }
    
    // ✅ SOLO verificar permisos (sin notificaciones de prueba)
    String permissionStatus = await IOSPlatformManager.checkCurrentPermissionStatus();
    if (mounted) setState(() => _notificationPermissionStatus = permissionStatus);
    
    // ✅ SOLO verificar inicialización
    try {
      await IOSPlatformManager.initialize();
      if (mounted) setState(() => _iosManagerStatus = "Inicializado OK");
    } catch (e) {
      if (mounted) setState(() => _iosManagerStatus = "Error: $e");
    }
    
    if (mounted) setState(() => _notificationDebugStatus = "Sistema listo");
    
  } catch (e) {
    if (mounted) setState(() {
      _notificationDebugStatus = "Error: $e";
      _lastNotificationError = e.toString();
    });
  }
}


 



 
// ✅ FUNCIÓN DEBUG para iOS
Future<void> _debugiOSConfiguration() async {
  print("🧪 === DEBUG CONFIGURACIÓN iOS ===");
  
  // Verificar datos guardados
  print("📋 Datos actuales:");
  print("   - IMEI: ${BleData.imei}");
  print("   - MAC Address: ${BleData.macAddress}");
  print("   - conBoton: ${BleData.conBoton}");
  print("   - SOS Number: ${BleData.sosNumber}");
  
  // Verificar permisos
  bool locationAlways = await Permission.locationAlways.isGranted;
  bool bluetooth = await Permission.bluetooth.isGranted;
  bool notification = await Permission.notification.isGranted;
  
  print("📋 Permisos iOS:");
  print("   - Ubicación siempre: ${locationAlways ? '✅' : '❌'}");
  print("   - Bluetooth: ${bluetooth ? '✅' : '❌'}");
  print("   - Notificaciones: ${notification ? '✅' : '❌'}");
  
  // Verificar servicios
  bool gpsEnabled = await Geolocator.isLocationServiceEnabled();
  BluetoothAdapterState bleState = await FlutterBluePlus.adapterState.first;
  
  print("📋 Servicios del sistema:");
  print("   - GPS: ${gpsEnabled ? '✅' : '❌'}");
  print("   - Bluetooth: $bleState");
  
  print("🧪 === FIN DEBUG ===");
}

Future<void> _debugBLEConnection() async {
  print("🔵 === DEBUG BLE CONNECTION ===");
  
  // Verificar datos básicos
  print("📋 Datos BLE:");
  print("   - MAC Address guardado: '${BleData.macAddress}'");
  print("   - conBoton: ${BleData.conBoton}");
  print("   - IMEI: ${BleData.imei}");
  
  // Verificar estado Bluetooth
  try {
    BluetoothAdapterState bleState = await FlutterBluePlus.adapterState.first;
    print("🔵 Estado Bluetooth: $bleState");
    
    if (bleState == BluetoothAdapterState.on) {
      print("✅ Bluetooth está encendido");
      
      // Verificar dispositivos conectados
      List<BluetoothDevice> connectedDevices = await FlutterBluePlus.connectedDevices;
      print("📱 Dispositivos conectados: ${connectedDevices.length}");
      
      for (var device in connectedDevices) {
        print("   - ${device.remoteId} (${device.platformName})");
      }
      
      // Verificar si nuestro dispositivo está en la lista
      bool ourDeviceConnected = connectedDevices.any((device) => 
        device.remoteId.toString() == BleData.macAddress);
      print("🎯 Nuestro dispositivo conectado: $ourDeviceConnected");
      
    } else {
      print("❌ Bluetooth está apagado: $bleState");
    }
    
  } catch (e) {
    print("❌ Error verificando Bluetooth: $e");
  }
  
  print("🔵 === FIN DEBUG BLE ===");
}

Future<void> _setupiOSBLE() async {
  print("🍎 === CONFIGURANDO BLE PARA iOS ===");
  
  // ✅ NUEVO: Debug del estado antes de conectar
  BleData.debugConnectionState();
  
  // ✅ VERIFICAR si tenemos UUID temporal
  if (BleData.needsUuidUpdate()) {
    print("⚠️ iOS: Detectado UUID temporal - se actualizará al encontrar dispositivo");
    print("🔍 iOS: Buscará dispositivo con nombre 'Holy-IOT'");
  } else {
    print("✅ iOS: UUID válido encontrado: ${BleData.macAddress}");
  }
  
  // ✅ VERIFICAR estado Bluetooth antes de escanear
  BluetoothAdapterState bleState = await FlutterBluePlus.adapterState.first;
  if (bleState != BluetoothAdapterState.on) {
    print("❌ iOS: Bluetooth no está encendido: $bleState");
    return;
  }
  
  print("✅ iOS: Bluetooth está encendido, iniciando escaneo por nombre...");
  
  try {
    bool success = await startScanAndConnect();
    if (success) {
      print("✅ iOS: BLE configurado exitosamente");
    } else {
      print("⚠️ iOS: No se pudo conectar inmediatamente");
      print("🔄 iOS: Seguirá intentando automáticamente cada 30 segundos");
    }
  } catch (e) {
    print("❌ iOS: Error configurando BLE: $e");
  }
  
  print("🍎 === FIN CONFIGURACIÓN BLE iOS ===");
}


  // ✅ MANTENER: Inicialización Android existente
// ✅ MANTENER: Inicialización Android existente COMPLETA
Future<void> _initializeAndroid() async {
  print("🤖 Inicializando estrategia Android existente...");
  
  _setupLifecycleListener();
  
  // Inicializar estados anteriores
  previousConnectionState = BleData.isConnected;
  previousLocationConfirmed = BleData.locationConfirmed;

  // Inicializar el último estado de conectividad conocido
  Connectivity().checkConnectivity().then((result) {
    _lastConnectivityResult = result;
    print("🌐 Estado inicial de conectividad: $_lastConnectivityResult");
  });
  
  // Configurar el listener de cambios de conectividad
  _setupConnectivityListener();

  locationService.initializeDeviceId().then((_) {
    print("Device ID inicializado correctamente: ${BleData.deviceId}");

    if (BleData.conBoton == 1) {
      requestPermissions().then((_) {
        Future.delayed(Duration(seconds: 3), () async {
          await verifyPermissionsAfterStartup();
          
          bool locationAlwaysGranted = await Permission.locationAlways.isGranted;
          bool phoneGranted = await Permission.phone.isGranted;
          
          if (!locationAlwaysGranted || !phoneGranted) {
            print("⚠️ Faltan permisos críticos, mostrando pantalla de configuración...");
            if (_isMounted && navigatorKey.currentContext != null) {
              // ✅ NAVEGACIÓN CONDICIONAL CORREGIDA
              if (Platform.isIOS) {
                Navigator.push(
                  navigatorKey.currentContext!,
                  MaterialPageRoute(builder: (context) => const IOSPermissionGuidePage()),
                );
              } else {
                Navigator.push(
                  navigatorKey.currentContext!,
                  MaterialPageRoute(builder: (context) => const PermissionGuidePage()),
                );
              }
            }
          }
        });
        
        startForegroundTask();
        startScanAndConnect();
        if (!locationService.isUpdatingLocation) {
          locationService.startLocationUpdates();
        }
      });
    } else {
      requestPermissions().then((_) {
        Future.delayed(Duration(seconds: 3), () async {
          await verifyPermissionsAfterStartup();
          
          bool locationAlwaysGranted = await Permission.locationAlways.isGranted;
          
          if (!locationAlwaysGranted) {
            print("⚠️ Falta permiso de ubicación siempre, mostrando pantalla de configuración...");
            if (_isMounted && navigatorKey.currentContext != null) {
              // ✅ NAVEGACIÓN CONDICIONAL CORREGIDA
              if (Platform.isIOS) {
                Navigator.push(
                  navigatorKey.currentContext!,
                  MaterialPageRoute(builder: (context) => const IOSPermissionGuidePage()),
                );
              } else {
                Navigator.push(
                  navigatorKey.currentContext!,
                  MaterialPageRoute(builder: (context) => const PermissionGuidePage()),
                );
              }
            }
          }
        });
        
        startForegroundTask();
        if (!locationService.isUpdatingLocation) {
          locationService.startLocationUpdates();
        }
      });
    }
  });

  // Iniciar monitor del servicio para asegurar que siempre esté activo
  startServiceMonitor();
  print("✅ BleScanPageState Android inicializado con listener de lifecycle");

  // Actualizar UI periódicamente
  Timer.periodic(const Duration(seconds: 2), (timer) {
    if (_isMounted) {
      setState(() {
        sosButtonColor = BleData.locationConfirmed ? Colors.green : Colors.grey;
        sosButtonText = BleData.locationConfirmed ? "Alerta SOS" : "Conectando...";
      });
    }
  });

  // Sistema Heartbeat para supervivencia (solo Android)
  startHeartbeatSystem();
  print("✅ BleScanPageState Android inicializado con HEARTBEAT SYSTEM");
}

  void _setupConnectivityListener() {
    // Solo para Android
    if (Platform.isIOS) return;
    
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
      print("🌐 Cambio de conectividad detectado: $_lastConnectivityResult -> $result");
      
      if ((_lastConnectivityResult == ConnectivityResult.mobile || 
           _lastConnectivityResult == ConnectivityResult.wifi) && 
          result == ConnectivityResult.none) {
        print("⚠️ Pérdida de conectividad detectada.");
        
        BleData.locationFailureCount = 0;
        print("🔄 Contador de fallos reseteado para comenzar a incrementarse");
        
        BleData.setLocationConfirmed(false);
      }
      else if (_lastConnectivityResult == ConnectivityResult.none && 
          (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi)) {
        print("🌐 Reconexión a Internet detectada. Verificando conexión real...");
        
        await Future.delayed(Duration(seconds: 1));
        
        bool realConnection = await BleData.isInternetConnected();
        if (realConnection) {
          print("✅ Conexión a Internet confirmada. Intentando enviar ubicación...");
          
          bool success = await locationService.sendLocationOnce();
          print("📡 Resultado del envío inmediato tras reconexión: ${success ? 'Exitoso' : 'Fallido'}");
        } else {
          print("⚠️ Falsa detección de conectividad. No hay conexión real a Internet.");
          BleData.setLocationConfirmed(false);
        }
      }
      
      _lastConnectivityResult = result;
    });
  }

  Future<void> startForegroundTask() async {
    // Solo para Android
    if (Platform.isIOS) {
      print("🍎 iOS no necesita foreground task - Background modes configurados automáticamente");
      return;
    }
    
    if (ForegroundService.isRunning) return;

    bool batteryPermissionGranted = await Permission.ignoreBatteryOptimizations.isGranted;
    if (!batteryPermissionGranted) {
      print("⚠️ No se tienen permisos de batería, el servicio podría ser limitado");
    } else {
      print("✅ Permisos de batería confirmados para el servicio");
    }
    
    bool hasPermissions = await Permission.notification.isGranted;
    if (!hasPermissions) {
      await Permission.notification.request();
    }
    
    ForegroundService.registerLocationServiceCallback(() {
      print("📡 Solicitud de envío de ubicación recibida desde el servicio");
      locationService.sendLocationOnce();
    });

    await ForegroundService.startForegroundTask();
    isForegroundServiceRunning = true;
    
    print("✅ Servicio en primer plano Android iniciado para mantener conexión BLE");
  }

  void _setupLifecycleListener() {
    // Solo para Android
    if (Platform.isIOS) return;
    
    _lifecycleChannel.setMethodCallHandler((call) async {
      if (call.method == 'appClosingPermanently') {
        print("🚨 SEÑAL RECIBIDA: App cerrando permanentemente");
        _appClosingPermanently = true;
        
        await _emergencyShutdown();
        
        return true;
      }
      return false;
    });
  }

  Future<void> _emergencyShutdown() async {
    print("🚨 === INICIO CIERRE DE EMERGENCIA ===");
    
    try {
       if (Platform.isIOS) {
      await IOSPlatformManager.dispose();
    }
      // 1. Cancelar TODOS los timers inmediatamente
      panicTimer?.cancel();
      updateTimer?.cancel();
      locationTimer?.cancel();
      retryScanTimer?.cancel();
      sosTimer?.cancel();
      backgroundReconnectionTimer?.cancel();
      _inactiveTimer?.cancel();
      _heartbeatTimer?.cancel();
      
      print("✅ Todos los timers cancelados");
      
      // 2. Detener ubicación
      locationService.stopLocationUpdates();
      print("✅ Servicio de ubicación detenido");
      
      // 3. Cancelar conectividad
      _connectivitySubscription?.cancel();
      print("✅ Suscripción de conectividad cancelada");
      
      // 4. ✅ DETENER servicio para eliminar notificación (solo Android)
      if (Platform.isAndroid && ForegroundService.isRunning) {
        print("🛑 Deteniendo servicio para eliminar notificación...");
        await FlutterForegroundTask.stopService();
        ForegroundService.isRunning = false;
        print("✅ Servicio detenido - notificación eliminada");
      }
      
      // 5. Limpiar datos
      BleData.dispose();
      print("✅ BleData limpiado");
      
      print("✅ Cierre de emergencia completado exitosamente");
      
    } catch (e) {
      print("❌ Error en cierre de emergencia: $e");
    }
    
    print("🚨 === FIN CIERRE DE EMERGENCIA ===");
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    print("🔄 Estado de la app: $state");

    // iOS maneja lifecycle automáticamente, Android necesita manejo manual
    if (Platform.isIOS) {
      print("🍎 iOS maneja lifecycle automáticamente");
      return;
    }

    // Solo para Android
    if (_appClosingPermanently) {
      print("🚨 App cerrando permanentemente - ignorando cambios de lifecycle");
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        await _onAppResumed();
        break;
        
      case AppLifecycleState.paused:
        await _onAppPaused();
        break;
        
      case AppLifecycleState.detached:
        if (!_appClosingPermanently) {
          print("❌ App detached sin señal de cierre - cierre inesperado");
          await _emergencyShutdown();
        } else {
          print("✅ App detached con señal de cierre permanente - normal");
        }
        break;
        
      default:
        print("ℹ️ Estado $state - no requiere acción");
        break;
    }
  }

  Future<void> _onAppResumed() async {
    print("🔺 App en primer plano");
    
    if (_appClosingPermanently) {
      print("⚠️ App cerrando - no restaurar servicios");
      return;
    }
    
    if (!ForegroundService.isRunning) {
      print("🔄 Reiniciando servicio al volver a primer plano");
      await startForegroundTask();
    }
    
    locationService.stopLocationUpdates();
    locationService.startLocationUpdates();
    print("📡 Servicio de ubicación reiniciado");
    
    if (BleData.conBoton == 1 && !BleData.isConnected) {
      print("🔵 Intentando reconexión BLE");
      handleReconnection();
    }
    
    if (_isMounted) {
      setState(() {});
    }
  }

  Future<void> _onAppPaused() async {
    print("🔻 App en segundo plano");
    
    if (_appClosingPermanently) {
      print("⚠️ App cerrando - no configurar para segundo plano");
      return;
    }
    
    print("📱 Manteniendo servicio activo en segundo plano");
    
    await locationService.sendLocationOnce();
    print("📡 Ubicación enviada antes de ir a segundo plano");
    
    if (BleData.conBoton == 1) {
      startBackgroundReconnection();
      print("🔵 Monitoreo BLE configurado para segundo plano");
    }
  }

  @override
  void dispose() {
    print("🧹 Limpiando recursos de BleScanPageState...");
    
    _isMounted = false;
    WidgetsBinding.instance.removeObserver(this);

    _heartbeatTimer?.cancel();
    print("💓 Sistema HEARTBEAT detenido");
    
    if (Platform.isIOS) {

      // 🔔 ELIMINAR NOTIFICACIÓN PERSISTENTE AL CERRAR APP
    print("🔔 Eliminando notificación persistente de servicio...");
    IOSPlatformManager.removePersistentMonitoringNotification().then((_) {
      print("✅ Notificación persistente eliminada al cerrar app");
    }).catchError((e) {
      print("❌ Error eliminando notificación persistente: $e");
    });


    IOSPlatformManager.dispose();
    print("✅ Dispose iOS completado con limpieza de notificación persistente");
    } else {
      // Solo limpiar si NO es cierre permanente (ya se limpió en emergencyShutdown)
      if (!_appClosingPermanently) {
 

        print("🧹 Realizando limpieza normal Android (no es cierre permanente)");
        
        // Cancelar timers
        _inactiveTimer?.cancel();
        panicTimer?.cancel();
        updateTimer?.cancel();
        locationTimer?.cancel();
        retryScanTimer?.cancel();
        sosTimer?.cancel();
        backgroundReconnectionTimer?.cancel();
        
        // Cancelar suscripción
        _connectivitySubscription?.cancel();
        
        // Detener ubicación
        locationService.stopLocationUpdates();
        
        print("✅ Limpieza normal Android completada");
      } else {
        print("✅ Dispose Android - limpieza ya realizada por emergencyShutdown");
      }
    }
    
    super.dispose();
  }

  // ✅ MÉTODOS AUXILIARES

  Future<bool> checkInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  void startBackgroundReconnection() {
    // Solo para Android
    if (Platform.isIOS || BleData.conBoton != 1) return;
    
    backgroundReconnectionTimer?.cancel();
    
    backgroundReconnectionTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (BleData.isConnected) {
        print("✅ Reconexión en segundo plano exitosa, deteniendo timer");
        timer.cancel();
        backgroundReconnectionTimer = null;
        return;
      }
      
      print("🔄 Intento de reconexión en segundo plano...");
      
      if (!BleData.isConnected && BleData.conBoton == 1) {
        try {
          if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on) {
            bool success = await startScanAndConnect();
            
            if (success) {
              print("✅ Reconexión en segundo plano exitosa, deteniendo timer");
              timer.cancel();
              backgroundReconnectionTimer = null;
            }
          } else {
            print("⚠️ Bluetooth desactivado durante reconexión en segundo plano");
            try {
              await FlutterBluePlus.turnOn();
            } catch (e) {
              print("Error al activar Bluetooth: $e");
            }
          }
        } catch (e) {
          print("❌ Error durante reconexión en segundo plano: $e");
        }
      }
    });
  }

  void startServiceMonitor() {
    // Solo para Android
    if (Platform.isIOS) return;
    
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      bool serviceActuallyRunning = await ForegroundService.isServiceRunning();
      
      if (!serviceActuallyRunning && ForegroundService.isRunning) {
        print("🚨 CRÍTICO: Servicio persistente se detuvo inesperadamente");
        ForegroundService.isRunning = false;
        
        if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
          print("🔄 Reiniciando servicio persistente de emergencia...");
          await startForegroundTask();
        }
      } else if (serviceActuallyRunning && !ForegroundService.isRunning) {
        print("🔄 Sincronizando estado del servicio persistente");
        ForegroundService.isRunning = true;
      }
    });
  }

  void startHeartbeatSystem() {
    // Solo para Android
    if (Platform.isIOS) return;
    
    print("💓 Iniciando sistema HEARTBEAT para supervivencia...");
    
    _heartbeatTimer?.cancel();
    
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      _heartbeatCount++;
      
      try {
        await updateHeartbeatNotification();
        await touchLocationSystem();
        await renewSystemLocks();
        await pingActivityToServer();
        await renewCriticalPermissions();
        
        print("💓 HEARTBEAT #$_heartbeatCount completado exitosamente");
        
      } catch (e) {
        print("❌ Error en HEARTBEAT #$_heartbeatCount: $e");
      }
    });
    
    print("✅ Sistema HEARTBEAT configurado - Latido cada 30 segundos");
  }

  Future<void> updateHeartbeatNotification() async {
    print("💓 Heartbeat silencioso #$_heartbeatCount ejecutado (sin notificación)");
  }

  Future<void> touchLocationSystem() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        print("💓 Location touch: Service=$serviceEnabled, Permission=$permission");
      }
    } catch (e) {
      print("⚠️ Error en location touch: $e");
    }
  }

  Future<void> renewSystemLocks() async {
    try {
      bool batteryOptimized = await Permission.ignoreBatteryOptimizations.isGranted;
      bool notificationPermission = await Permission.notification.isGranted;
      
      print("💓 System locks: Battery=$batteryOptimized, Notifications=$notificationPermission");
    } catch (e) {
      print("⚠️ Error renovando locks: $e");
    }
  }

  Future<void> pingActivityToServer() async {
    try {
      bool hasInternet = await checkInternetConnection();
      
      if (hasInternet) {
        bool internetReal = await BleData.isInternetConnected();
        print("💓 Server ping: Internet=$hasInternet, Real=$internetReal");
      } else {
        print("💓 Server ping: Sin conectividad");
      }
    } catch (e) {
      print("⚠️ Error en server ping: $e");
    }
  }
 
  Future<void> renewCriticalPermissions() async {
    try {
      PermissionStatus locationStatus = await Permission.location.status;
      PermissionStatus locationAlwaysStatus = await Permission.locationAlways.status;
      PermissionStatus notificationStatus = await Permission.notification.status;
      
      print("💓 Permissions: Location=$locationStatus, Always=$locationAlwaysStatus, Notifications=$notificationStatus");
    } catch (e) {
      print("⚠️ Error verificando permisos: $e");
    }
  }
  

Future<bool> startScanAndConnect() async {
  if (isScanning) return false;
  if (BleData.isConnected) return true;

  // ✅ INCREMENTAR contador de escaneos y resetear debug
  _scanAttempts++;
  _devicesFound = 0;
  _holyIotFound = 0;
  _targetDeviceFound = false;
  _foundDeviceNames.clear();
  _foundDeviceMacs.clear();
  _lastScanStatus = "Iniciando escaneo #$_scanAttempts";
  _scanDetails = "Buscando por nombre...";
  
  if (mounted) setState(() {});

  BluetoothAdapterState adapterState = await FlutterBluePlus.adapterState.first;
  if (adapterState != BluetoothAdapterState.on) {
    print("⚠️ Bluetooth apagado: $adapterState");
    _lastScanStatus = "ERROR: Bluetooth apagado";
    _scanDetails = "Estado: $adapterState";
    if (mounted) setState(() {});
    
    if (Platform.isIOS) {
      print("🍎 iOS: Usuario debe activar Bluetooth manualmente");
      return false;
    }
  }

  // ✅ ESTRATEGIA ESPECÍFICA POR PLATAFORMA
  String targetDeviceName = "Holy-IOT";
  
  if (Platform.isIOS) {
    print("🍎 === ESCANEO iOS POR NOMBRE ===");
    print("🔍 iOS busca SOLO por nombre: '$targetDeviceName'");
    print("📝 iOS ignora MAC Address del servidor: ${BleData.macAddress}");
    _lastScanStatus = "iOS: Buscando '$targetDeviceName' (ignora MAC)";
    _scanDetails = "iOS usa UUID dinámico, busca por nombre";
  } else {
    print("🤖 === ESCANEO ANDROID POR MAC ===");
    print("🔍 Android busca por MAC: ${BleData.macAddress}");
    _lastScanStatus = "Android: Buscando MAC ${BleData.macAddress}";
    _scanDetails = "Android usa MAC real del servidor";
  }
  
  isScanning = true;
  if (mounted) setState(() {});

  try {
    scanResults.clear();
    
    Duration scanTimeout = Platform.isIOS 
        ? const Duration(seconds: 25)  // iOS necesita más tiempo
        : const Duration(seconds: 8);   // Android rápido
    
    print("${Platform.isIOS ? '🍎' : '🤖'} Iniciando escaneo...");
    await FlutterBluePlus.startScan(timeout: scanTimeout);

    Completer<bool> connectionCompleter = Completer<bool>();
    StreamSubscription? subscription;
    bool deviceFound = false;

    subscription = FlutterBluePlus.scanResults.listen((results) {
      _devicesFound = results.length;
      _foundDeviceNames.clear();
      _foundDeviceMacs.clear();
      
      // ✅ CAPTURAR información de todos los dispositivos
      for (var result in results) {
        String deviceName = result.device.platformName.isNotEmpty 
            ? result.device.platformName 
            : "Sin nombre";
        _foundDeviceNames.add("$deviceName (${result.device.remoteId})");
        _foundDeviceMacs.add(result.device.remoteId.toString());
      }
      
      print("📱 Escaneo #$_scanAttempts: $_devicesFound dispositivos encontrados");
      
      // ✅ ESTRATEGIA DIFERENCIADA POR PLATAFORMA
      List<ScanResult> validResults = [];
      
      if (Platform.isIOS) {
        // ✅ iOS: SOLO buscar por nombre
        validResults = results
            .where((result) => result.device.platformName.toLowerCase() == targetDeviceName.toLowerCase())
            .toList();
        
        print("🍎 iOS: Dispositivos '$targetDeviceName' encontrados: ${validResults.length}");
        
        if (validResults.isNotEmpty) {
          for (var result in validResults) {
            print("🍎 iOS: - ${result.device.remoteId} | '$targetDeviceName' | RSSI: ${result.rssi}");
          }
        }
        
      } else {
        // ✅ Android: Buscar por MAC Address (estrategia original)
        validResults = results
            .where((result) => result.device.remoteId.toString() == BleData.macAddress)
            .toList();
        
        print("🤖 Android: Dispositivos con MAC ${BleData.macAddress}: ${validResults.length}");
      }
      
      _holyIotFound = validResults.length;
      _lastScanStatus = "Dispositivos válidos encontrados: $_holyIotFound de $_devicesFound";
      
      if (validResults.isNotEmpty) {
        // ✅ Si hay múltiples, elegir el de mejor RSSI
        if (validResults.length > 1) {
          print("⚠️ Múltiples dispositivos encontrados, eligiendo el más cercano:");
          for (var result in validResults) {
            print("   - ${result.device.remoteId} | RSSI: ${result.rssi}");
          }
          
          validResults.sort((a, b) => b.rssi.compareTo(a.rssi));
          print("✅ Elegido el más cercano: ${validResults.first.device.remoteId} (RSSI: ${validResults.first.rssi})");
        }
        
        deviceFound = true;
        _targetDeviceFound = true;
        
        if (_isMounted) {
          setState(() {
            scanResults = [validResults.first];
          });
        }
        
        FlutterBluePlus.stopScan();
        isScanning = false;
        retryScanTimer?.cancel();

        // ✅ CRÍTICO: GUARDAR EL IDENTIFICADOR CORRECTO SEGÚN LA PLATAFORMA
        String deviceIdentifier = validResults.first.device.remoteId.toString();
        
        if (Platform.isIOS) {
          print("🍎 iOS: Guardando UUID dinámico: $deviceIdentifier");
          print("🍎 iOS: Reemplazando MAC del servidor (${BleData.macAddress}) con UUID");
          BleData.setMacAddress(deviceIdentifier); // ✅ Guardar UUID dinámico
          _scanDetails = "iOS: MAC actualizado a UUID dinámico";
        } else {
          print("🤖 Android: Confirmando MAC Address: $deviceIdentifier");
          _scanDetails = "Android: MAC confirmado del servidor";
        }

        connectToDevice(
          validResults.first.device,
          navigatorKey.currentContext!,
          discoverServices,
          triggerUpdateTimer,
          activateSos,
        );

        if (!connectionCompleter.isCompleted) {
          connectionCompleter.complete(true);
          BleData.reconnectionAttemptCount = 0;
          print("✅ Dispositivo encontrado y conexión iniciada");
        }

        subscription?.cancel();
      } else {
        // No se encontró el dispositivo objetivo
        if (Platform.isIOS) {
          _lastScanStatus = "iOS: Sin '$targetDeviceName' en $_devicesFound dispositivos";
          _scanDetails = "iOS necesita dispositivo con nombre exacto";
        } else {
          _lastScanStatus = "Android: Sin MAC ${BleData.macAddress} en $_devicesFound";
          _scanDetails = "Android necesita MAC específico del servidor";
        }
      }
      
      if (mounted) setState(() {});
    });

    // ✅ TIMEOUT con logging específico por plataforma
    Duration timeoutDuration = Platform.isIOS 
        ? const Duration(seconds: 30)
        : const Duration(seconds: 12);
    
    Future.delayed(timeoutDuration, () {
      if (!connectionCompleter.isCompleted) {
        if (Platform.isIOS) {
          print("⏱️ iOS: Timeout escaneo #$_scanAttempts buscando '$targetDeviceName'");
          _lastScanStatus = "iOS TIMEOUT - '$targetDeviceName' no encontrado";
          if (_devicesFound > 0) {
            _scanDetails = "$_devicesFound dispositivos, ninguno llamado '$targetDeviceName'";
            print("🔍 iOS: Dispositivos encontrados pero sin nombre correcto:");
            for (int i = 0; i < _foundDeviceNames.length && i < 5; i++) {
              print("   - ${_foundDeviceNames[i]}");
            }
          } else {
            _scanDetails = "iOS: Sin dispositivos BLE detectados";
          }
        } else {
          print("⏱️ Android: Timeout escaneo #$_scanAttempts buscando MAC ${BleData.macAddress}");
          _lastScanStatus = "Android TIMEOUT - MAC no encontrado";
        }
        
        FlutterBluePlus.stopScan();
        isScanning = false;
        
        if (!BleData.isConnected) {
          Duration retryDelay = Platform.isIOS 
              ? const Duration(seconds: 30) 
              : const Duration(seconds: 15);
          
          retryScanTimer?.cancel();
          retryScanTimer = Timer(retryDelay, () {
            if (!BleData.isConnected) {
              print("🔄 Programando escaneo #${_scanAttempts + 1}...");
              startScanAndConnect();
            }
          });
          
          connectionCompleter.complete(false);
        }
        
        if (mounted) setState(() {});
      }
    });

    return connectionCompleter.future;
  } catch (e) {
    print("❌ Error durante escaneo #$_scanAttempts: $e");
    _lastScanStatus = "ERROR: $e";
    _scanDetails = "Excepción durante escaneo";
    isScanning = false;
    if (mounted) setState(() {});
    return false;
  }
}


  void promptToEnableBluetooth() async {
    print("⚠️ Mostrando alerta para activar Bluetooth...");
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (context) {
        return AlertDialog(
          title: const Text("Bluetooth Desactivado"),
          content: const Text("Para conectar al dispositivo BLE, debes activar el Bluetooth."),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await enableBluetooth();
                startScanAndConnect();
              },
              child: const Text("Activar Bluetooth"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancelar"),
            ),
          ],
        );
      },
    );
  }

  Future<void> enableBluetooth() async {
    if (BleData.conBoton != 1) return;
    if (!(await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on)) {
      await FlutterBluePlus.turnOn();
      print("✅ Bluetooth activado");
    } else {
      print("ℹ️ Bluetooth ya estaba activado.");
    }
  }

  Future<void> handleReconnection() async {
    // Solo para Android
    if (Platform.isIOS) {
      print("🍎 iOS: Reconexión automática por Apple - No acción manual");
      return;
    }
    
    if (isReconnecting || BleData.isConnected) {
      print("⚠️ Android: No iniciar reconexión: isReconnecting=$isReconnecting, conectado=${BleData.isConnected}");
      return;
    }
    
    isReconnecting = true;
    
    BleData.reconnectionAttemptCount++;
    print("🔄 Intentando reconectar BLE... Intento #${BleData.reconnectionAttemptCount}/${BleData.maxReconnectionAttemptsBeforeNotification}");

    if (BleData.reconnectionAttemptCount == BleData.maxReconnectionAttemptsBeforeNotification && 
        BleData.bleNotificationsEnabled) {
      print("📱 NOTIFICACIÓN DE DESCONEXIÓN BLE - Intento #${BleData.reconnectionAttemptCount}");
      
      BleData.bleDisconnectionNotificationShown = true;
      BleData.markDisconnectionNotificationShown();
      print("🔔 Bandera bleDisconnectionNotificationShown configurada a true");
      
      CommunicationService().showBleDisconnectedNotification();
    }

    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print("Advertencia: No se pudo detener el escaneo: $e");
    }
    
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      print("⚠️ Bluetooth apagado, intentando activar...");
      try {
        await FlutterBluePlus.turnOn();
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print("❌ No se pudo activar el Bluetooth: $e");
        isReconnecting = false;
        return;
      }
    }

    bool success = await startScanAndConnect(); 

    if (success) {
      print("✅ Reconexión exitosa.");
      BleData.reconnectionAttemptCount = 0;
      print("✅ Contador de reconexión reiniciado a 0, bleDisconnectionNotificationShown=${BleData.bleDisconnectionNotificationShown}");
    } else {
      print("❌ No se pudo reconectar, intentando nuevamente en segundo plano.");
      print("⚠️ Estado actual: reconnectionAttemptCount=${BleData.reconnectionAttemptCount}, bleDisconnectionNotificationShown=${BleData.bleDisconnectionNotificationShown}");
      
      if (!isForegroundServiceRunning) {
        startForegroundTask();
      }
    }

    isReconnecting = false; 
  }

  Future<int> readBatteryLevel(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        if (service.uuid.toString().toUpperCase() == '6E400001-B5A3-F393-E0A9-E50E24DCCA9E') {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() == '6E400002-B5A3-F393-E0A9-E50E24DCCA9E' &&
                characteristic.properties.write) {
              await characteristic.write([0xF3, 0x16, 0xF3]);
              print("Comando de batería enviado: F3 16 F3");
            }

            if (characteristic.uuid.toString().toUpperCase() == '6E400003-B5A3-F393-E0A9-E50E24DCCA9E' &&
                characteristic.properties.notify) {
              await characteristic.setNotifyValue(true);

              await for (List<int> value in characteristic.lastValueStream) {
                print("Datos de la batería recibidos: $value");

                if (value.length >= 5 &&
                    value[0] == 0xF3 &&
                    value[1] == 0x16 &&
                    value[2] == 0xF3) {
                  int len = value[3];
                  if (len >= 1) {
                    int batteryLevel = value[4];
                    print("Nivel de batería recibido: $batteryLevel%");
                    return batteryLevel;
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print("Error al leer el nivel de batería: $e");
    }

    return 0;
  }

  void startUpdateTimer() {
    // Solo para Android
    if (Platform.isIOS) return;
    
    updateTimer?.cancel();
    updateDeviceData();

    updateTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (_isMounted) {
        if (BleData.isConnected) {
          print("Actualizando datos del dispositivo BLE conectado...");
        } else {
          print("Verificando estado de conexión BLE...");
        }
        updateDeviceData();
      } else {
        timer.cancel();
      }
    });
  }

  void triggerUpdateTimer() {
    startUpdateTimer();
  }

  void stopUpdateTimer() {
    if (updateTimer != null) {
      updateTimer!.cancel();
      updateTimer = null;
      print("🛑 Timer de actualización de BLE detenido.");
    }
  }

  Future<void> updateDeviceData() async {
    if (!_isMounted) return;
    
    if (BleData.conBoton == 2) return;

    if (BleData.isConnected) {
      try {
        List<BluetoothDevice> connectedDevices = await FlutterBluePlus.connectedDevices;
        BluetoothDevice? connectedDevice;
        
        for (var device in connectedDevices) {
          if (device.remoteId.toString() == BleData.macAddress) {
            connectedDevice = device;
            break;
          }
        }
        
        if (connectedDevice != null) {
          try {
            int rssi = await connectedDevice.readRssi();
            int batteryLevel = await readBatteryLevel(connectedDevice);
            
            if (_isMounted) {
              setState(() {
                BleData.update(
                  newMacAddress: connectedDevice!.remoteId.toString(),
                  newBatteryLevel: batteryLevel,
                  newRssi: rssi,
                  connectionStatus: true,
                );
              });
            }
            
            return;
          } catch (e) {
            print("Error al actualizar datos del dispositivo conectado: $e");
          }
        }
      } catch (e) {
        print("Error al verificar dispositivos conectados: $e");
      }
    }

    bool anyDeviceConnected = false;

    for (var result in scanResults) {
      final device = result.device;
      
      if (device.remoteId.toString() != BleData.macAddress) continue;

      try {
        device.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) {
            if (_isMounted) {
              setState(() {
                BleData.update(
                  newMacAddress: device.remoteId.toString(),
                  connectionStatus: false,
                );
              });
            }
            print("Dispositivo ${device.remoteId} desconectado.");
          }
        });

        if (await device.connectionState.first == BluetoothConnectionState.connected) {
          anyDeviceConnected = true;
          int rssi = await device.readRssi();
          int batteryLevel = await readBatteryLevel(device);

          if (_isMounted) {
            setState(() {
              BleData.update(
                newMacAddress: device.remoteId.toString(),
                newBatteryLevel: batteryLevel,
                newRssi: rssi,
                connectionStatus: true,
              );
            });
          }
        }
      } catch (e) {
        print("Error al actualizar datos del dispositivo ${device.remoteId}: $e");
      }
    }

    if (!anyDeviceConnected && !BleData.isConnected) {
      print("No hay dispositivos conectados. Reiniciando escaneo...");
      await handleReconnection();
    } else if (!anyDeviceConnected && BleData.isConnected) {
      print("Estado del BLE: conectado según BleData pero no verificado en escaneo.");
    }
  }

  void startSosTimer() {
    sosTimer = Timer(const Duration(seconds: 3), () {
      if (isSosPressed) {
        setState(() {
          isSosActivated = true;
          sosButtonColor = Colors.red;
          sosButtonText = "SOS ACTIVADO!";
        });

        if (BleData.sosSoundEnabled) {
          CommunicationService().playSosSound();
        }

        CommunicationService().sendSosAlert(BleData.macAddress);
        CommunicationService().bringToForeground(); 

        if (BleData.autoCall) {
          Future.delayed(const Duration(seconds: 1), () {
            CommunicationService().callSosNumber();
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Alerta SOS enviada")),
        );
      }
    });
  }

  void cancelSosTimer() {
    sosTimer?.cancel();
    setState(() {
      isSosPressed = false;
    });
  }

  void deactivateSos() {
    setState(() {
      isSosActivated = false;
      sosButtonColor = Colors.green;
      sosButtonText = "Alerta SOS";
    });
  }

  void activateSos() {
    if (mounted) {
      setState(() {
        isSosActivated = true;
        sosButtonColor = Colors.red;
        sosButtonText = "SOS ACTIVADO!";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;
    final isPortrait = orientation == Orientation.portrait;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          Platform.isIOS ? '🍎 BLE SOS App' : '🤖 BLE SOS App',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Platform.isIOS ? Colors.blue : Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: isPortrait
            ? _buildPortraitLayout(size)
            : _buildLandscapeLayout(size),
      ),
    );
  }

  Widget _buildPortraitLayout(Size size) {
    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.04,
              vertical: size.height * 0.02,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ✅ DEBUG CONTAINER AMPLIADO CON NOTIFICACIONES
           /*     Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8), // ✅ Reducir padding para más espacio
                  margin: const EdgeInsets.only(bottom: 12), // ✅ Reducir margen
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "🚨 DEBUG BLE + NOTIFICACIONES",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12, // ✅ Reducir font
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 4), // ✅ Reducir espacio
                      
                      // ✅ SECCIÓN 1: NOTIFICACIONES (NUEVA)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("🔔 NOTIFICACIONES:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9)),
                            Text("Estado: $_notificationDebugStatus", style: TextStyle(fontSize: 8)),
                            Text("Permisos: $_notificationPermissionStatus", style: TextStyle(fontSize: 8)),
                            Text("iOS Manager: $_iosManagerStatus", style: TextStyle(fontSize: 8)),
                            Text("Local: $_localNotificationStatus", style: TextStyle(fontSize: 8)),
                            Text("Intentos: $_notificationAttempts | Éxitos: $_notificationSuccesses", style: TextStyle(fontSize: 8)),
                            Text("Última prueba: $_lastNotificationTest", style: TextStyle(fontSize: 7)),
                            if (_lastNotificationError != "Ninguno")
                              Text("Error: $_lastNotificationError", style: TextStyle(fontSize: 7, color: Colors.red)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      
                      // ✅ SECCIÓN 2: BLE (CÓDIGO EXISTENTE COMPACTADO)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _sosServiceFound ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _sosServiceFound ? Colors.green.shade200 : Colors.orange.shade200
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("🎯 BLE:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9)),
                            Text("Conectado: ${BleData.isConnected ? '✅' : '❌'} | Servicios: $_totalServices", style: TextStyle(fontSize: 8)),
                            Text("SOS Service: ${_sosServiceFound ? '✅' : '❌'} | Write: ${_writeCharFound ? '✅' : '❌'}", style: TextStyle(fontSize: 8)),
                            Text("Notify: ${_notifyCharFound ? '✅' : '❌'} | Paquetes: $_dataPacketsReceived", style: TextStyle(fontSize: 8)),
                            Text("Botón: $_buttonStatus | Acción: $_lastButtonAction", style: TextStyle(fontSize: 7)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      
                      // ✅ SECCIÓN 3: SISTEMA (COMPACTADA)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                                Text("📱 SISTEMA:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9)),
                                Text("${Platform.isIOS ? 'iOS' : 'Android'} | BT: $_bluetoothState", style: TextStyle(fontSize: 8)),
                                
                                // ✅ NUEVO: Mostrar estado de MAC/UUID
                                if (Platform.isIOS) ...[
                                  Text("UUID: ${BleData.macAddress.length > 15 ? BleData.macAddress.substring(0, 15) + '...' : BleData.macAddress}", style: TextStyle(fontSize: 8)),
                                  Text("¿Temporal?: ${BleData.needsUuidUpdate() ? '⚠️ SÍ' : '✅ NO'}", style: TextStyle(fontSize: 8)),
                                ] else ...[
                                  Text("MAC: ${BleData.macAddress.length > 12 ? BleData.macAddress.substring(0, 12) + '...' : BleData.macAddress}", style: TextStyle(fontSize: 8)),
                                ],
                                
                                Text("IMEI: ${BleData.imei.length > 8 ? BleData.imei.substring(0, 8) + '...' : BleData.imei}", style: TextStyle(fontSize: 8)),
                              ],
                        ),
                      ),
                      
                      const SizedBox(height: 2),
                      Text(
                        "⏰ ${DateTime.now().toString().substring(11, 19)}",
                        style: TextStyle(fontSize: 7, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
            */
 // ✅ CIERRE CORRECTO DEL CONTAINER PRINCIPAL
              
              if (BleData.conBoton == 1) ...[
                Container(
                  width: size.width * 0.92,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
                  ),
                  child: scanResults.isNotEmpty
                    ? ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: scanResults.length,
                        itemBuilder: (context, index) {
                          final result = scanResults[index];
                          final macAddress = result.device.remoteId.toString();
                          return _buildDeviceInfoTile(result.device, macAddress);
                        },
                      )
                    : BleData.macAddress != "N/A" && BleData.macAddress.isNotEmpty
                        ? _buildDeviceInfoTile(null, BleData.macAddress)
                        : const Center(
                            child: Text(
                              "Esperando dispositivo...",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                ),

                if (Platform.isIOS && !BleData.isConnected) 
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ElevatedButton(
                        onPressed: () async {
                          await _runDiagnostic();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          "🔧 DIAGNÓSTICO BLE",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                
                if (!BleData.isConnected)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    alignment: Alignment.center,
                    child: Text(
                      "Buscando Dispositivo ${BleData.macAddress}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
              ] else ...[
                Container(
                  width: size.width * 0.92,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Conexión a dispositivo BLE Deshabilitada",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        
        Positioned(
          left: 0,
          right: 0,
          top: size.height * 0.45,
          child: _buildVerticalSosSection(size),
        ),
      ],
    ),
  );
}

  Widget _buildLandscapeLayout(Size size) {
    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.05,
              vertical: size.height * 0.02,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (BleData.conBoton == 1) ...[
                  Container(
                    width: size.width * 0.9,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: scanResults.isNotEmpty
                      ? ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: scanResults.length,
                          itemBuilder: (context, index) {
                            final result = scanResults[index];
                            final macAddress = result.device.remoteId.toString();
                            return _buildDeviceInfoTileLandscape(result.device, macAddress);
                          },
                        )
                      : BleData.macAddress != "N/A" && BleData.macAddress.isNotEmpty
                          ? _buildDeviceInfoTileLandscape(null, BleData.macAddress)
                          : const Center(
                              child: Text(
                                "Esperando dispositivo...",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                  ),
                  
                  if (!BleData.isConnected)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      alignment: Alignment.center,
                      child: Text(
                        "Buscando Dispositivo ${BleData.macAddress}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                ] else ...[
                  Container(
                    width: size.width * 0.9,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Conexión a dispositivo BLE Deshabilitada",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          Positioned(
            left: 0,
            right: 0,
            top: size.height * 0.4,
            child: Center(
              child: _buildHorizontalSosSection(size),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildDeviceInfoTile(BluetoothDevice? device, String macAddress) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10.0),
    decoration: BoxDecoration(
      color: BleData.isConnected ? const Color(0xFFE8F5E9) : Colors.grey[100],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: BleData.isConnected ? Colors.green.shade300 : Colors.grey.shade300, width: 1.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              BleData.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: BleData.isConnected ? Colors.green : Colors.red,
              size: 24,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: BleData.isConnected ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                BleData.isConnected ? 'Conectado' : 'Desconectado',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 6),
        
        Text(
          device != null && device.platformName.isNotEmpty
              ? device.platformName
              : 'Holy-IOT',
          style: const TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 4),
        
        // ✅ MOSTRAR INFORMACIÓN ESPECÍFICA POR PLATAFORMA
        if (Platform.isIOS) ...[
          Text(
            "UUID iOS: ${macAddress.length > 20 ? macAddress.substring(0, 20) + '...' : macAddress}",
            style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
          ),
          if (BleData.needsUuidUpdate())
            Text(
              "⚠️ UUID temporal - se actualizará al conectar",
              style: TextStyle(fontSize: 12.0, color: Colors.orange[700], fontStyle: FontStyle.italic),
            ),
        ] else ...[
          Text(
            "MAC: $macAddress",
            style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
          ),
        ],
        
        const SizedBox(height: 4),
        
        Text(
          "Batería: ${BleData.batteryLevel > 0 ? "${BleData.batteryLevel}%" : "N/A"}",
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            color: BleData.batteryLevel > 20 ? Colors.green[700] : Colors.orange[700],
          ),
        ),
        
        const SizedBox(height: 4),
        
        Text(
          "RSSI: ${BleData.rssi} dBm",
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            color: BleData.rssi > -80 ? Colors.blue[700] : Colors.grey[600],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildDeviceInfoTileLandscape(BluetoothDevice? device, String macAddress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: BleData.isConnected ? const Color(0xFFE8F5E9) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BleData.isConnected ? Colors.green.shade300 : Colors.grey.shade300, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      BleData.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: BleData.isConnected ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: BleData.isConnected ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        BleData.isConnected ? 'Conectado' : 'Desconectado',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.0,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                Text(
                  device != null && device.platformName.isNotEmpty
                      ? device.platformName
                      : 'Dispositivo BLE',
                  style: const TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                Text(
                  "MAC: $macAddress",
                  style: const TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          Container(
            height: 50,
            width: 1,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      BleData.batteryLevel > 80 ? Icons.battery_full :
                      BleData.batteryLevel > 50 ? Icons.battery_6_bar :
                      BleData.batteryLevel > 20 ? Icons.battery_3_bar :
                      Icons.battery_1_bar,
                      color: BleData.batteryLevel > 20 ? Colors.green : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Batería: ${BleData.batteryLevel > 0 ? "${BleData.batteryLevel}%" : "N/A"}",
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: BleData.batteryLevel > 20 ? Colors.green[700] : Colors.orange[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                Row(
                  children: [
                    Icon(
                      BleData.rssi > -80 ? Icons.signal_cellular_alt : 
                      BleData.rssi > -90 ? Icons.signal_cellular_alt_2_bar : 
                      Icons.signal_cellular_alt_1_bar,
                      color: BleData.rssi > -80 ? Colors.blue : Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "RSSI: ${BleData.rssi} dBm",
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: BleData.rssi > -80 ? Colors.blue[700] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalSosSection(Size size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTapDown: (_) {
            setState(() => isSosPressed = true);
            startSosTimer();
          },
          onTapUp: (_) => cancelSosTimer(),
          onTapCancel: () => cancelSosTimer(),
          child: Container(
            width: size.width * 0.5,
            height: size.width * 0.5,
            decoration: BoxDecoration(
              color: isSosActivated ? Colors.red : sosButtonColor,
              borderRadius: BorderRadius.circular(size.width * 0.25),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  spreadRadius: 3,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              sosButtonText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        
        SizedBox(height: size.height * 0.04),
        
        if (isSosActivated)
          SizedBox(
            width: size.width * 0.5,
            child: ElevatedButton(
              onPressed: deactivateSos,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.06,
                  vertical: size.height * 0.015,
                ),
              ),
              child: const Text(
                "Desactivar SOS",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHorizontalSosSection(Size size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTapDown: (_) {
            setState(() => isSosPressed = true);
            startSosTimer();
          },
          onTapUp: (_) => cancelSosTimer(),
          onTapCancel: () => cancelSosTimer(),
          child: Container(
            width: size.height * 0.29,
            height: size.height * 0.29,
            decoration: BoxDecoration(
              color: isSosActivated ? Colors.red : sosButtonColor,
              borderRadius: BorderRadius.circular(size.height * 0.145),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  spreadRadius: 3,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              sosButtonText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22 * 1.15,
                fontWeight: FontWeight.bold, 
                color: Colors.white
              ),
            ),
          ),
        ),
        
        SizedBox(width: size.width * 0.05),
        
        if (isSosActivated)
          ElevatedButton(
            onPressed: deactivateSos,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.04,
                vertical: size.height * 0.02,
              ),
              textStyle: TextStyle(
                fontSize: 16 * 1.15,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text("Desactivar SOS"),
          ),
      ],
    );
  }
}

// ============================================================================
// 📋 RESUMEN DE CAMBIOS IMPLEMENTADOS EN MAIN.DART
// ============================================================================

/*
✅ INCLUYE TODAS LAS ACTUALIZACIONES:

1. IMPORTS NECESARIOS:
   - dart:io para Platform.isIOS ✅
   - Imports comentados para iOS (ios_permission_guide.dart) ✅

2. DETECCIÓN DE PLATAFORMA:
   - Inicialización específica iOS vs Android ✅
   - Permisos específicos por plataforma ✅

3. NAVEGACIÓN CONDICIONAL:
   - Navigator.push con Platform.isIOS check ✅
   - Temporalmente usa PermissionGuidePage para iOS ✅
   - Lista para IOSPermissionGuidePage cuando esté listo ✅

4. MÉTODOS ESPECÍFICOS:
   - _initializeiOS() - Sin timers agresivos ✅
   - _initializeAndroid() - Mantiene funcionalidad completa ✅
   - Todos los métodos con Platform.isIOS checks ✅

5. UI DIFERENCIADA:
   - AppBar azul para iOS, verde para Android ✅
   - Títulos con emojis 🍎 iOS y 🤖 Android ✅

6. LIFECYCLE MANAGEMENT:
   - iOS: Manejo automático por Apple ✅
   - Android: Manejo manual completo ✅

7. FUNCIONALIDAD PRESERVADA:
   - Android: 100% idéntico a versión actual ✅
   - iOS: Configuración básica preparada para expansión ✅

PRÓXIMOS PASOS:
1. Crear ios_permission_guide.dart
2. Descomentar imports iOS en main.dart
3. Testing en ambas plataformas
*/
