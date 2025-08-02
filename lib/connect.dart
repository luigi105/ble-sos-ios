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
    print("Estado conexión: ${await device.connectionState.first}");
    
    // ✅ VERIFICAR ESTADO DE CONEXIÓN PRIMERO
    BluetoothConnectionState connectionState = await device.connectionState.first;
    if (connectionState != BluetoothConnectionState.connected) {
      print("❌ DISPOSITIVO NO CONECTADO: $connectionState");
      return;
    }
    
    print("✅ Dispositivo confirmado como conectado");
    
    // ✅ DESCUBRIR SERVICIOS CON TIMEOUT
    print("🔍 Iniciando descubrimiento de servicios...");
    List<BluetoothService> services;
    
    try {
      services = await device.discoverServices().timeout(Duration(seconds: 10));
      print("✅ Descubrimiento completado");
    } catch (e) {
      print("❌ Error o timeout en descubrimiento: $e");
      return;
    }
    
    print("📋 === ANÁLISIS COMPLETO DE SERVICIOS ===");
    print("Total servicios encontrados: ${services.length}");
    
    if (services.isEmpty) {
      print("❌ ¡NO SE ENCONTRARON SERVICIOS!");
      print("Esto indica un problema de conexión o configuración del dispositivo");
      return;
    }
    
    // ✅ LISTAR TODOS LOS SERVICIOS ENCONTRADOS
    for (int i = 0; i < services.length; i++) {
      var service = services[i];
      String serviceUuid = service.uuid.toString();
      print("📁 Servicio $i: $serviceUuid");
      
      // ✅ VERIFICAR SI ES EL SERVICIO QUE BUSCAMOS
      String targetService = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
      bool isTargetService = serviceUuid.toLowerCase() == targetService.toLowerCase();
      
      print("   ¿Es el servicio SOS? ${isTargetService ? '✅ SÍ' : '❌ NO'}");
      
      if (isTargetService) {
        print("   🎯 ¡SERVICIO SOS ENCONTRADO!");
      }
      
      // ✅ LISTAR TODAS LAS CARACTERÍSTICAS
      try {
        print("   Características (${service.characteristics.length}):");
        
        if (service.characteristics.isEmpty) {
          print("   ⚠️ Sin características encontradas");
        }
        
        for (int j = 0; j < service.characteristics.length; j++) {
          var characteristic = service.characteristics[j];
          String charUuid = characteristic.uuid.toString();
          
          print("   📝 Característica $j: $charUuid");
          print("      Propiedades:");
          print("        - Read: ${characteristic.properties.read}");
          print("        - Write: ${characteristic.properties.write}");
          print("        - Notify: ${characteristic.properties.notify}");
          print("        - Indicate: ${characteristic.properties.indicate}");
          
          // ✅ VERIFICAR CARACTERÍSTICAS ESPECÍFICAS
          String writeTarget = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
          String notifyTarget = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
          
          bool isWriteChar = charUuid.toLowerCase() == writeTarget.toLowerCase();
          bool isNotifyChar = charUuid.toLowerCase() == notifyTarget.toLowerCase();
          
          if (isWriteChar) {
            print("      🔧 ¡CARACTERÍSTICA WRITE ENCONTRADA!");
          }
          if (isNotifyChar) {
            print("      🔔 ¡CARACTERÍSTICA NOTIFY ENCONTRADA!");
          }
        }
      } catch (e) {
        print("   ❌ Error obteniendo características: $e");
      }
      
      print(""); // Línea en blanco para separar servicios
    }
    
    // ✅ BUSCAR Y CONFIGURAR EL SERVICIO SOS
    bool sosServiceFound = false;
    BluetoothCharacteristic? writeCharacteristic;
    BluetoothCharacteristic? notifyCharacteristic;
    
    print("🎯 === BUSCANDO SERVICIO SOS ESPECÍFICO ===");
    
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
        
        // ✅ NOTIFICAR AL DEBUG
        if (_updateSosDebug != null) {
          _updateSosDebug!("servicioEncontrado", true);
        }
        
        // ✅ BUSCAR CARACTERÍSTICAS ESPECÍFICAS
        print("🔍 Buscando características write y notify...");
        
        for (var characteristic in service.characteristics) {
          String charUuid = characteristic.uuid.toString().toLowerCase();
          
          // Write characteristic: 6E400002-B5A3-F393-E0A9-E50E24DCCA9E
          if (charUuid == "6e400002-b5a3-f393-e0a9-e50e24dcca9e") {
            writeCharacteristic = characteristic;
            print("✅ Característica WRITE confirmada");
            print("   UUID: $charUuid");
            print("   Puede escribir: ${characteristic.properties.write}");
          }
          
          // Notify characteristic: 6E400003-B5A3-F393-E0A9-E50E24DCCA9E  
          if (charUuid == "6e400003-b5a3-f393-e0a9-e50e24dcca9e") {
            notifyCharacteristic = characteristic;
            print("✅ Característica NOTIFY confirmada");
            print("   UUID: $charUuid");
            print("   Puede notificar: ${characteristic.properties.notify}");
          }
        }
        
        break; // Solo necesitamos este servicio
      }
    }
    
    // ✅ RESULTADO DEL DESCUBRIMIENTO
    print("📊 === RESUMEN DE DESCUBRIMIENTO ===");
    print("Servicios totales: ${services.length}");
    print("Servicio SOS encontrado: ${sosServiceFound ? '✅ SÍ' : '❌ NO'}");
    print("Característica Write: ${writeCharacteristic != null ? '✅ SÍ' : '❌ NO'}");
    print("Característica Notify: ${notifyCharacteristic != null ? '✅ SÍ' : '❌ NO'}");
    
    if (!sosServiceFound) {
      print("❌ PROBLEMA: Servicio SOS no encontrado");
      print("💡 Posibles causas:");
      print("   1. Dispositivo no tiene el servicio configurado");
      print("   2. UUID del servicio es diferente");
      print("   3. Dispositivo no está completamente conectado");
      print("   4. Problema de firmware del dispositivo BLE");
      
      print("🔍 Servicios disponibles para análisis:");
      for (var service in services) {
        print("   - ${service.uuid}");
      }
      return;
    }
    
    if (writeCharacteristic == null || notifyCharacteristic == null) {
      print("❌ PROBLEMA: Características necesarias no encontradas");
      print("Write encontrada: ${writeCharacteristic != null}");
      print("Notify encontrada: ${notifyCharacteristic != null}");
      return;
    }
    
    // ✅ CONFIGURAR NOTIFICACIONES
    print("🔔 === CONFIGURANDO NOTIFICACIONES ===");
    
    try {
      await notifyCharacteristic.setNotifyValue(true);
      print("✅ Notificaciones activadas exitosamente");
      
      // ✅ CONFIGURAR LISTENER
      notifyCharacteristic.value.listen((value) {
        print("📡 === DATOS RECIBIDOS ===");
        print("Timestamp: ${DateTime.now().toString().substring(11, 19)}");
        print("Datos: $value");
        print("Hex: ${value.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}");
        
        // ✅ ACTUALIZAR DEBUG
        if (_updateSosDebug != null) {
          _updateSosDebug!("datosRecibidos", value);
        }
        
        // ✅ PROCESAR SEGÚN PROTOCOLO
        if (value.isNotEmpty && value.length >= 4) {
          if (value.length >= 5 && 
              value[0] == 0xF3 && 
              value[1] == 0x15 && 
              value[2] == 0xF3) {
            
            print("🔘 COMANDO BOTÓN detectado");
            int buttonState = value[4];
            print("Estado: $buttonState (${buttonState == 1 ? 'PRESIONADO' : 'SOLTADO'})");
            
            if (buttonState == 1) {
              print("🚨 ¡BOTÓN SOS PRESIONADO!");
              
              if (_updateSosDebug != null) {
                _updateSosDebug!("botonPresionado", buttonState);
              }
              
              if (!buttonPressed && panicTimer == null) {
                buttonPressed = true;
                panicTimer = Timer(const Duration(seconds: 3), () {
                  if (buttonPressed) {
                    print("🚨 ¡EJECUTANDO ALERTA SOS!");
                    
                    if (BleData.sosSoundEnabled) {
                      CommunicationService().playSosSound();
                    }
                    CommunicationService().bringToForeground();  
                    onSosActivated();
                    CommunicationService().sendSosAlert(device.remoteId.toString());
                    showPanicAlert(context, device.remoteId.toString());
                    
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
              
              if (_updateSosDebug != null) {
                _updateSosDebug!("botonSoltado", buttonState);
              }
              
              if (panicTimer != null && panicTimer!.isActive) {
                panicTimer!.cancel();
                panicTimer = null;
              }
              buttonPressed = false;
            }
          }
        }
      });
      
    } catch (e) {
      print("❌ Error configurando notificaciones: $e");
      return;
    }
    
    // ✅ ENVIAR COMANDO INICIAL
    print("📝 === ENVIANDO COMANDOS INICIALES ===");
    
    try {
      // Comando batería: F3 16 F3
      List<int> batteryCommand = [0xF3, 0x16, 0xF3];
      await writeCharacteristic.write(batteryCommand);
      print("✅ Comando batería enviado: ${batteryCommand.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}");
      
      await Future.delayed(Duration(milliseconds: 500));
      print("✅ Configuración completa");
      
    } catch (e) {
      print("❌ Error enviando comandos: $e");
    }
    
    print("🔍 === FIN DEBUG DESCUBRIMIENTO ===");
    
  } catch (e) {
    print("❌ Error general en discoverServices: $e");
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