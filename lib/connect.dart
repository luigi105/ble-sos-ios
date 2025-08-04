import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'coms.dart';
import 'dart:async';
import 'ble_data.dart';
import 'dart:io';

bool buttonPressed = false;
Timer? panicTimer;

// ✅ AÑADIR esta variable global para capturar errores BLE
String _lastBleError = "Ninguno";

// ✅ FUNCIÓN para obtener el último error (puede ser llamada desde main.dart)
String getLastBleError() => _lastBleError;
Function? _updateSosDebug;

void setSosDebugCallback(Function callback) {
  _updateSosDebug = callback;
}

// ✅ REEMPLAZAR connectToDevice con versión híbrida iOS/Android
void connectToDevice(BluetoothDevice device, BuildContext context, Function discoverServicesCallback, Function triggerUpdateTimerCallback, Function onSosActivated) async {
  try {
    print("🔗 Intento de conexión con: ${device.remoteId}");

    if (Platform.isIOS) {
      print("🍎 === CONEXIÓN BLE iOS HÍBRIDA ===");
      _lastBleError = "Iniciando conexión iOS";
      
      // ✅ VERIFICAR estado actual de conexión primero
      BluetoothConnectionState state = await device.connectionState.first;
      if (state == BluetoothConnectionState.connected) {
        print("✅ iOS: Dispositivo ya conectado");
        _lastBleError = "Ya conectado iOS";
        BleData.update(
          newMacAddress: device.remoteId.toString(),
          connectionStatus: true,
        );
        await Future.delayed(Duration(seconds: 1));
        discoverServicesCallback(device, context, onSosActivated);
        triggerUpdateTimerCallback();
        return;
      }
      
      // ✅ DETENER escaneo antes de conectar (crítico para iOS)
      try {
        await FlutterBluePlus.stopScan();
        await Future.delayed(Duration(milliseconds: 500)); // Pausa para iOS
        print("🍎 iOS: Escaneo detenido antes de conectar");
      } catch (e) {
        print("⚠️ iOS: Advertencia al detener escaneo: $e");
      }
      
      // ✅ CANCELAR conexiones anteriores
      BleData.cancelConnectionSubscription();
      
      try {
        // ✅ CONEXIÓN OPTIMIZADA PARA iOS
        await device.connect(
          autoConnect: true,  // ✅ CRÍTICO para iOS - permite reconexión automática
          timeout: const Duration(seconds: 30),
        );
        
        _lastBleError = "Conexión inicial iOS exitosa";
        print("✅ iOS: Conexión inicial exitosa");
        
        // ✅ VERIFICAR estado después de conectar
        BluetoothConnectionState currentState = await device.connectionState.first;
        print("🔍 iOS: Estado post-conexión: $currentState");
        
        if (currentState == BluetoothConnectionState.connected) {
          BleData.update(
            newMacAddress: device.remoteId.toString(),
            connectionStatus: true,
          );
          
          // ✅ PEQUEÑA PAUSA antes de descubrir servicios (iOS necesita tiempo)
          await Future.delayed(Duration(seconds: 1));
          discoverServicesCallback(device, context, onSosActivated);
          triggerUpdateTimerCallback();
        }
        
      } catch (e) {
        _lastBleError = "Error conexión inicial iOS: $e";
        print("❌ iOS: Error conexión inicial: $e");
        
        // ✅ SEGUNDO INTENTO sin autoConnect
        try {
          await Future.delayed(Duration(seconds: 2));
          await device.connect(
            autoConnect: false,  // Sin autoConnect en segundo intento
            timeout: const Duration(seconds: 20),
          );
          _lastBleError = "Reconexión iOS exitosa";
          print("✅ iOS: Reconexión exitosa");
        } catch (retryError) {
          _lastBleError = "Falló reconexión iOS: $retryError";
          print("❌ iOS: Falló reconexión: $retryError");
          return; // Salir si ambos intentos fallan
        }
      }
      
      // ✅ CONFIGURAR LISTENER de estado permanente para iOS
      StreamSubscription<BluetoothConnectionState> connectionStateSubscription;
      connectionStateSubscription = device.connectionState.listen((newState) {
        print("🔵 iOS Estado cambió: $newState");
        
        if (newState == BluetoothConnectionState.connected) {
          _lastBleError = "Conectado y operativo iOS";
          BleData.update(
            newMacAddress: device.remoteId.toString(),
            connectionStatus: true,
          );
          BleData.saveConnectionState(true);
          print("✅ iOS: Conexión confirmada y guardada");
          
        } else if (newState == BluetoothConnectionState.disconnected) {
          _lastBleError = "Desconectado iOS - autoConnect activo";
          print("⚠️ iOS: Dispositivo desconectado - iOS intentará reconectar automáticamente");
          BleData.update(
            newMacAddress: device.remoteId.toString(),
            connectionStatus: false,
          );
          BleData.saveConnectionState(false);
          
          // ✅ iOS con autoConnect=true debería reconectar automáticamente
          // No forzar reconexión manual - dejar que iOS lo maneje
          print("🍎 iOS: Esperando reconexión automática por autoConnect...");
        }
      });
      
      // ✅ ALMACENAR suscripción para limpieza posterior
      BleData.connectionSubscription = connectionStateSubscription;
      
    } else {
      // ✅ ANDROID: Usar lógica original que ya funciona
      print("🤖 === CONEXIÓN BLE ANDROID (Original) ===");
      _lastBleError = "Iniciando conexión Android";
      
      // Verificar el estado actual de conexión
      BluetoothConnectionState state = await device.connectionState.first;

      // Si ya está conectado, no hacer nada más
      if (state == BluetoothConnectionState.connected) {
        print("✅ Android: Dispositivo ya conectado: ${device.remoteId}");
        _lastBleError = "Ya conectado Android";
        BleData.update(
          newMacAddress: device.remoteId.toString(),
          connectionStatus: true,
        );
        discoverServicesCallback(device, context, onSosActivated);
        triggerUpdateTimerCallback();
        return;
      }

      // Detener cualquier escaneo activo
      try {
        await FlutterBluePlus.stopScan();
        print("🤖 Android: Escaneo detenido para iniciar conexión.");
      } catch (e) {
        print("⚠️ Android: Advertencia al detener escaneo: $e");
      }

      // Cancelar cualquier suscripción anterior para evitar fugas de memoria
      BleData.cancelConnectionSubscription();

      // Intentar conectar con el dispositivo
      try {
        await device.connect(
          timeout: const Duration(seconds: 15),
          // Sin autoConnect para Android (como en versión original)
        );
        _lastBleError = "Conexión Android exitosa";
        print("✅ Android: Conexión inicial exitosa");
      } catch (e) {
        _lastBleError = "Error conexión Android: $e";
        print("❌ Android: Error en conexión inicial: $e");
        // Intentar nuevamente sin autoConnect
        try {
          await device.connect(timeout: const Duration(seconds: 30));
          _lastBleError = "Reconexión Android exitosa";
        } catch (secondError) {
          _lastBleError = "Falló reconexión Android: $secondError";
          print("❌ Android: Error en segundo intento de conexión: $secondError");
          return; // Si falla dos veces, salir
        }
      }

      // Configurar listener permanente para el estado de conexión (Android)
      StreamSubscription<BluetoothConnectionState> connectionStateSubscription;
      connectionStateSubscription = device.connectionState.listen((newState) {
        print("🤖 Android: Estado del dispositivo ${device.remoteId}: $newState");
        
        if (newState == BluetoothConnectionState.connected) {
          _lastBleError = "Conectado y operativo Android";
          print("✅ Android: Conexión exitosa: ${device.remoteId}");
          BleData.update(
            newMacAddress: device.remoteId.toString(),
            connectionStatus: true,
          );
          BleData.saveConnectionState(true);
          
          // Descubrir servicios y configurar notificaciones
          discoverServicesCallback(device, context, onSosActivated);
          
          // Iniciar actualización periódica de datos
          triggerUpdateTimerCallback();
        } 
        else if (newState == BluetoothConnectionState.disconnected) {
          _lastBleError = "Desconectado Android - programando reconexión";
          print("❌ Android: Dispositivo desconectado: ${device.remoteId}");
          BleData.update(
            newMacAddress: device.remoteId.toString(),
            connectionStatus: false,
          );
          BleData.saveConnectionState(false);
          
          // Intentar reconectar automáticamente después de una desconexión (Android)
          Future.delayed(const Duration(seconds: 8), () {
            if (!BleData.isConnected) {
              print("🔄 Android: Intentando reconexión automática después de desconexión...");
              try {
                device.connect(timeout: const Duration(seconds: 30)).catchError((e) {
                  _lastBleError = "Error reconexión automática Android: $e";
                  print("❌ Android: Error en reconexión automática: $e");
                });
              } catch (e) {
                _lastBleError = "Excepción reconexión Android: $e";
                print("❌ Android: Excepción en reconexión automática: $e");
              }
            }
          });
        }
      });
      
      // Almacenar la suscripción para poder cancelarla cuando sea necesario
      BleData.connectionSubscription = connectionStateSubscription;
    }
    
  } catch (e) {
    _lastBleError = "Error general: $e";
    print("❌ Error general al intentar conectar con el dispositivo: $e");

    // Verificar si el error es el código 133 (ANDROID_SPECIFIC_ERROR)
    if (e.toString().contains("133") && Platform.isAndroid) {
      promptToToggleBluetooth();
    }
  }
}

// Mostrar mensaje al usuario para que reinicie manualmente el Bluetooth
void promptToToggleBluetooth() {
  print("No se puede desactivar Bluetooth automáticamente. Solicita al usuario que lo reinicie manualmente.");
  // Puedes mostrar un diálogo visual
}

// ✅ REEMPLAZAR discoverServices en connect.dart con versión que sigue el protocolo:

// ✅ REEMPLAZAR discoverServices en connect.dart con versión de debug completo:

void discoverServices(BluetoothDevice device, BuildContext context, Function onSosActivated ) async {
  try {
    print("🔍 === DEBUG COMPLETO DESCUBRIMIENTO BLE ===");
    print("Dispositivo: ${device.remoteId}");
    print("Nombre: ${device.platformName}");
    
    // ✅ NOTIFICAR INICIO DEL DESCUBRIMIENTO
    if (_updateSosDebug != null) {
      _updateSosDebug!("discoveryStart", "Iniciando descubrimiento...");
    }
    
    // ✅ VERIFICAR ESTADO DE CONEXIÓN
    BluetoothConnectionState connectionState = await device.connectionState.first;
    print("Estado conexión: $connectionState");
    
    if (connectionState != BluetoothConnectionState.connected) {
      print("❌ DISPOSITIVO NO CONECTADO: $connectionState");
      if (_updateSosDebug != null) {
        _updateSosDebug!("discoveryStart", "ERROR: No conectado");
      }
      return;
    }
    
    print("✅ Dispositivo confirmado como conectado");
    if (_updateSosDebug != null) {
      _updateSosDebug!("discoveryStart", "Conectado, descubriendo...");
    }
    
    // ✅ DESCUBRIR SERVICIOS CON TIMEOUT
    print("🔍 Iniciando descubrimiento de servicios...");
    List<BluetoothService> services;
    
    try {
      services = await device.discoverServices().timeout(Duration(seconds: 10));
      print("✅ Descubrimiento completado");
    } catch (e) {
      print("❌ Error o timeout en descubrimiento: $e");
      if (_updateSosDebug != null) {
        _updateSosDebug!("discoveryStart", "ERROR: Timeout descubrimiento");
      }
      return;
    }
    
    print("📋 Total servicios encontrados: ${services.length}");
    
    // ✅ NOTIFICAR SERVICIOS ENCONTRADOS
    if (_updateSosDebug != null) {
      _updateSosDebug!("servicesFound", {
        'total': services.length,
        'uuids': services.map((s) => s.uuid.toString()).toList()
      });
    }
    
    if (services.isEmpty) {
      print("❌ ¡NO SE ENCONTRARON SERVICIOS!");
      if (_updateSosDebug != null) {
        _updateSosDebug!("discoveryStart", "ERROR: Sin servicios");
      }
      return;
    }
    
    // ✅ LISTAR TODOS LOS SERVICIOS ENCONTRADOS
    print("📋 === SERVICIOS ENCONTRADOS ===");
    for (int i = 0; i < services.length; i++) {
      var service = services[i];
      String serviceUuid = service.uuid.toString();
      print("📁 Servicio $i: $serviceUuid");
      
      String targetService = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
      bool isTargetService = serviceUuid.toLowerCase() == targetService.toLowerCase();
      print("   ¿Es servicio SOS? ${isTargetService ? '✅ SÍ' : '❌ NO'}");
      
      // ✅ LISTAR CARACTERÍSTICAS
      print("   Características (${service.characteristics.length}):");
      for (int j = 0; j < service.characteristics.length; j++) {
        var characteristic = service.characteristics[j];
        String charUuid = characteristic.uuid.toString();
        print("   📝 Característica $j: $charUuid");
        print("      Read: ${characteristic.properties.read}");
        print("      Write: ${characteristic.properties.write}");
        print("      Notify: ${characteristic.properties.notify}");
      }
    }
    
    // ✅ BUSCAR Y CONFIGURAR EL SERVICIO SOS
    bool sosServiceFound = false;
    BluetoothCharacteristic? writeCharacteristic;
    BluetoothCharacteristic? notifyCharacteristic;
    
    print("🎯 === BUSCANDO SERVICIO SOS ===");
    
    for (var service in services) {
      String serviceUuid = service.uuid.toString().toLowerCase();
      String targetServiceUuid = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
      
      print("🔍 Comparando:");
      print("   Encontrado: '$serviceUuid'");
      print("   Buscando:   '$targetServiceUuid'");
      print("   ¿Coincide?  ${serviceUuid == targetServiceUuid}");
      
      if (serviceUuid == targetServiceUuid) {
        sosServiceFound = true;
        print("✅ ¡SERVICIO SOS CONFIRMADO!");
        
        // ✅ NOTIFICAR SERVICIO SOS ENCONTRADO
        if (_updateSosDebug != null) {
          _updateSosDebug!("sosServiceFound", true);
        }
        
        print("🔍 Buscando características write y notify...");
        
        for (var characteristic in service.characteristics) {
          String charUuid = characteristic.uuid.toString().toLowerCase();
          
          // Write characteristic: 6E400002-B5A3-F393-E0A9-E50E24DCCA9E
          if (charUuid == "6e400002-b5a3-f393-e0a9-e50e24dcca9e") {
            writeCharacteristic = characteristic;
            print("✅ Característica WRITE confirmada: $charUuid");
            
            // ✅ NOTIFICAR WRITE ENCONTRADA
            if (_updateSosDebug != null) {
              _updateSosDebug!("writeCharFound", true);
            }
          }
          
          // Notify characteristic: 6E400003-B5A3-F393-E0A9-E50E24DCCA9E  
          if (charUuid == "6e400003-b5a3-f393-e0a9-e50e24dcca9e") {
            notifyCharacteristic = characteristic;
            print("✅ Característica NOTIFY confirmada: $charUuid");
            
            // ✅ NOTIFICAR NOTIFY ENCONTRADA
            if (_updateSosDebug != null) {
              _updateSosDebug!("notifyCharFound", true);
            }
          }
        }
        
        break; // Solo necesitamos este servicio
      }
    }
    
    // ✅ VERIFICAR RESULTADO
    print("📊 === RESUMEN ===");
    print("Servicio SOS: ${sosServiceFound ? '✅' : '❌'}");
    print("Write: ${writeCharacteristic != null ? '✅' : '❌'}");
    print("Notify: ${notifyCharacteristic != null ? '✅' : '❌'}");
    
    if (!sosServiceFound) {
      print("❌ SERVICIO SOS NO ENCONTRADO");
      if (_updateSosDebug != null) {
        _updateSosDebug!("configStatus", "ERROR: Sin servicio SOS");
      }
      return;
    }
    
    if (writeCharacteristic == null || notifyCharacteristic == null) {
      print("❌ CARACTERÍSTICAS FALTANTES");
      if (_updateSosDebug != null) {
        _updateSosDebug!("configStatus", "ERROR: Sin características");
      }
      return;
    }
    
    // ✅ CONFIGURAR NOTIFICACIONES
    print("🔔 === CONFIGURANDO NOTIFICACIONES ===");
    
    try {
      await notifyCharacteristic.setNotifyValue(true);
      print("✅ Notificaciones activadas");
      
      // ✅ NOTIFICAR CONFIGURACIÓN EXITOSA
      if (_updateSosDebug != null) {
        _updateSosDebug!("configStatus", "Notificaciones activadas");
      }
      
      // ✅ CONFIGURAR LISTENER
      notifyCharacteristic.value.listen((value) {
        print("📡 === DATOS RECIBIDOS ===");
        print("Timestamp: ${DateTime.now().toString().substring(11, 19)}");
        print("Datos: $value");
        print("Hex: ${value.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}");
        
        // ✅ NOTIFICAR DATOS RECIBIDOS
        if (_updateSosDebug != null) {
          _updateSosDebug!("dataReceived", value);
        }
        
        // ✅ PROCESAR SEGÚN PROTOCOLO
        if (value.isNotEmpty && value.length >= 4) {
          // Verificar comando botón: F3 15 F3 LEN XX
          if (value.length >= 5 && 
              value[0] == 0xF3 && 
              value[1] == 0x15 && 
              value[2] == 0xF3) {
            
            print("🔘 COMANDO BOTÓN detectado");
            int buttonState = value[4];
            print("Estado botón: $buttonState (${buttonState == 1 ? 'PRESIONADO' : 'SOLTADO'})");
            
            if (buttonState == 1) {
              print("🚨 ¡BOTÓN SOS PRESIONADO!");
              
              // ✅ NOTIFICAR BOTÓN PRESIONADO
              if (_updateSosDebug != null) {
                _updateSosDebug!("buttonPressed", buttonState);
              }
              
              if (!buttonPressed && panicTimer == null) {
                print("✅ Iniciando secuencia SOS (3 segundos)...");
                buttonPressed = true;
                
                panicTimer = Timer(const Duration(seconds: 3), () {
                  if (buttonPressed) {
                    print("🚨 ¡EJECUTANDO ALERTA SOS!");
                    
                    // 🔊 Reproducir sonido
                    if (BleData.sosSoundEnabled) {
                      CommunicationService().playSosSound();
                    }
                    
                    // 🔹 Traer app al frente
                    CommunicationService().bringToForeground();  
                    
                    // ✅ Actualizar UI
                    onSosActivated();
                    
                    // 📌 Enviar alerta
                    CommunicationService().sendSosAlert(device.remoteId.toString());
                    showPanicAlert(context, device.remoteId.toString());
                    
                    // 📞 Llamada automática
                    if (BleData.autoCall) {
                      Future.delayed(const Duration(seconds: 1), () {
                        CommunicationService().callSosNumber();
                      });
                    }
                  }
                  panicTimer = null;
                });
              }
              
            } else if (buttonState == 0) {
              print("🔘 Botón soltado");
              
              // ✅ NOTIFICAR BOTÓN SOLTADO
              if (_updateSosDebug != null) {
                _updateSosDebug!("buttonReleased", buttonState);
              }
              
              if (panicTimer != null && panicTimer!.isActive) {
                print("❌ Cancelando timer SOS");
                panicTimer!.cancel();
                panicTimer = null;
              }
              buttonPressed = false;
            }
          }
          // Verificar comando batería: F3 16 F3 LEN XX
          else if (value.length >= 5 && 
                   value[0] == 0xF3 && 
                   value[1] == 0x16 && 
                   value[2] == 0xF3) {
            
            int batteryPercent = value[4];
            print("🔋 Batería: $batteryPercent%");
            BleData.update(newBatteryLevel: batteryPercent);
          }
          else {
            print("❓ Datos no reconocidos:");
            for (int i = 0; i < value.length; i++) {
              print("  Byte $i: 0x${value[i].toRadixString(16).padLeft(2, '0')} (${value[i]})");
            }
          }
        }
        
        print("📡 === FIN DATOS ===");
      }, onError: (error) {
        print("❌ Error en listener: $error");
        if (_updateSosDebug != null) {
          _updateSosDebug!("configStatus", "ERROR: Listener falló");
        }
      });
      
    } catch (e) {
      print("❌ Error configurando notificaciones: $e");
      if (_updateSosDebug != null) {
        _updateSosDebug!("configStatus", "ERROR: Configuración falló");
      }
      return;
    }
    
    // ✅ ENVIAR COMANDOS INICIALES
    print("📝 === ENVIANDO COMANDOS ===");
    
    try {
      // Comando batería: F3 16 F3
      List<int> batteryCommand = [0xF3, 0x16, 0xF3];
      await writeCharacteristic.write(batteryCommand);
      print("✅ Comando batería enviado: ${batteryCommand.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}");
      
      await Future.delayed(Duration(milliseconds: 500));
      
      if (_updateSosDebug != null) {
        _updateSosDebug!("configStatus", "Comandos enviados OK");
      }
      
      print("✅ Configuración BLE completa");
      
    } catch (e) {
      print("❌ Error enviando comandos: $e");
      if (_updateSosDebug != null) {
        _updateSosDebug!("configStatus", "ERROR: Comandos fallaron");
      }
    }
    
    print("🔍 === FIN CONFIGURACIÓN ===");
    
  } catch (e) {
    print("❌ Error general en discoverServices: $e");
    if (_updateSosDebug != null) {
      _updateSosDebug!("configStatus", "ERROR: Excepción general");
    }
  }
}


Future<bool> startScanAndConnectSimple() async {
  print("🔍 === CONEXIÓN SIMPLIFICADA ===");
  
  if (BleData.conBoton != 1) {
    print("❌ BLE no habilitado (conBoton = ${BleData.conBoton})");
    return false;
  }
  
  try {
    // Verificar Bluetooth
    BluetoothAdapterState adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      print("❌ Bluetooth apagado");
      return false;
    }
    
    print("✅ Bluetooth OK, escaneando...");
    
    // Detener escaneo previo
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      // Ignorar
    }
    
    // Escaneo
    await FlutterBluePlus.startScan(timeout: Duration(seconds: 20));
    
    BluetoothDevice? foundDevice;
    StreamSubscription? subscription;
    Completer<BluetoothDevice?> deviceCompleter = Completer<BluetoothDevice?>();
    
    subscription = FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        if (result.device.platformName.toLowerCase() == "holy-iot") {
          foundDevice = result.device;
          print("✅ Holy-IOT encontrado: ${result.device.remoteId}");
          
          FlutterBluePlus.stopScan();
          subscription?.cancel();
          
          if (!deviceCompleter.isCompleted) {
            deviceCompleter.complete(result.device);
          }
          return;
        }
      }
    });
    
    // Timeout
    Timer(Duration(seconds: 25), () {
      if (!deviceCompleter.isCompleted) {
        FlutterBluePlus.stopScan();
        subscription?.cancel();
        deviceCompleter.complete(null);
      }
    });
    
    foundDevice = await deviceCompleter.future;
    
    // ✅ VERIFICACIÓN NULL Y RETURN TEMPRANO
    if (foundDevice == null) {
      print("❌ Holy-IOT no encontrado");
      return false;
    }
    
    // ✅ AHORA foundDevice NO PUEDE SER NULL - usar operador !
    print("🔗 Intentando conectar con ${foundDevice!.remoteId}...");
    
    try {
      await foundDevice!.connect(
        autoConnect: Platform.isIOS, // Solo autoConnect en iOS
        timeout: Duration(seconds: 20),
      );
      
      // Verificar conexión
      BluetoothConnectionState state = await foundDevice!.connectionState.first;
      if (state == BluetoothConnectionState.connected) {
        print("✅ Conexión exitosa!");
        
        // Actualizar datos
        String deviceUuid = foundDevice!.remoteId.toString();
        
        // Llamar setMacAddress sin await problemático
        BleData.setMacAddress(deviceUuid).then((_) {
          print("💾 UUID guardado: $deviceUuid");
        }).catchError((e) {
          print("⚠️ Error guardando UUID: $e");
        });
        
        // Actualizar estado inmediatamente
        BleData.update(
          newMacAddress: deviceUuid,
          connectionStatus: true,
        );
        
        print("✅ Conexión confirmada: $deviceUuid");
        return true;
      } else {
        print("❌ Conexión falló - Estado: $state");
        return false;
      }
      
    } catch (e) {
      print("❌ Error durante conexión: $e");
      return false;
    }
    
  } catch (e) {
    print("❌ Error en conexión simplificada: $e");
    return false;
  }
}



void showPanicAlert(BuildContext context, String bleMacAddress) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("¡Alerta de Pánico!"),
        content: Text("Botón de pánico presionado en el dispositivo: $bleMacAddress"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Cerrar"),
          ),
        ],
      );
    },
  );
}

Future<void> debugBluetoothSystem() async {
  print("🔍 === DIAGNÓSTICO COMPLETO SISTEMA BLE ===");
  
  try {
    // 1. Verificar estado Bluetooth
    BluetoothAdapterState adapterState = await FlutterBluePlus.adapterState.first;
    print("📶 Estado Bluetooth: $adapterState");
    
    // 2. Verificar plataforma
    print("📱 Plataforma: ${Platform.isIOS ? 'iOS' : 'Android'}");
    
    // 3. Verificar datos guardados
    print("💾 Datos guardados:");
    print("   - conBoton: ${BleData.conBoton}");
    print("   - IMEI: ${BleData.imei}");
    print("   - MAC/UUID: ${BleData.macAddress}");
    print("   - SOS Number: ${BleData.sosNumber}");
    
    // 4. Verificar conexión actual
    print("🔗 Estado conexión:");
    print("   - isConnected: ${BleData.isConnected}");
    print("   - isScanning: $isScanning");
    
    // 5. Verificar dispositivos conectados
    List<BluetoothDevice> connectedDevices = await FlutterBluePlus.connectedDevices;
    print("📱 Dispositivos conectados: ${connectedDevices.length}");
    for (var device in connectedDevices) {
      print("   - ${device.remoteId} | '${device.platformName}'");
    }
    
    // 6. Verificar si IOSPlatformManager está inicializado
    if (Platform.isIOS) {
      print("🍎 IOSPlatformManager inicializado: ${IOSPlatformManager.isIOS}");
    }
    
  } catch (e) {
    print("❌ Error en diagnóstico: $e");
  }
  
  print("🔍 === FIN DIAGNÓSTICO ===");
}

Future<bool> basicScanForHolyIot() async {
  print("🔍 === ESCANEO BÁSICO HOLY-IOT ===");
  
  try {
    // Verificar Bluetooth
    BluetoothAdapterState adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      print("❌ Bluetooth apagado: $adapterState");
      return false;
    }
    
    print("✅ Bluetooth encendido, iniciando escaneo...");
    
    // Escaneo corto para diagnóstico
    await FlutterBluePlus.startScan(timeout: Duration(seconds: 10));
    
    bool holyIotFound = false;
    
    await for (List<ScanResult> results in FlutterBluePlus.scanResults) {
      print("📡 Escaneo: ${results.length} dispositivos encontrados");
      
      for (var result in results) {
        String deviceName = result.device.platformName.isNotEmpty 
            ? result.device.platformName 
            : "Sin nombre";
        print("   - ${result.device.remoteId} | '$deviceName' | RSSI: ${result.rssi}");
        
        if (deviceName.toLowerCase() == "holy-iot") {
          print("🎯 ¡HOLY-IOT ENCONTRADO!");
          print("   UUID/MAC: ${result.device.remoteId}");
          print("   RSSI: ${result.rssi}");
          holyIotFound = true;
          
          // Guardar el identificador correcto
          String deviceId = result.device.remoteId.toString();
          BleData.setMacAddress(deviceId);
          print("💾 Identificador guardado: $deviceId");
          
          break;
        }
      }
      
      if (holyIotFound) break;
    }
    
    await FlutterBluePlus.stopScan();
    
    if (holyIotFound) {
      print("✅ Holy-IOT encontrado y datos actualizados");
      return true;
    } else {
      print("❌ Holy-IOT no encontrado");
      return false;
    }
    
  } catch (e) {
    print("❌ Error en escaneo básico: $e");
    return false;
  }
}
