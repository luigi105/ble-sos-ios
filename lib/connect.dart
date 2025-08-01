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

void discoverServices(BluetoothDevice device, BuildContext context, Function onSosActivated ) async {
  try {
    print("Descubriendo servicios del dispositivo: ${device.remoteId}");
    List<BluetoothService> services = await device.discoverServices();

    for (var service in services) {
      if (service.uuid.toString() == '6e400001-b5a3-f393-e0a9-e50e24dcca9e') {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            characteristic.value.listen((value) {
              if (value.isNotEmpty) {
                print("Valor recibido: $value");

                if (value[4] == 1 && !buttonPressed && panicTimer == null) {
                  buttonPressed = true;
                  panicTimer = Timer(const Duration(seconds: 3), () {
                    if (buttonPressed) {
                      print("¡Botón SOS presionado! Generando alerta...");
                      
                      // 🔊 Reproducir sonido de alerta
                      if (BleData.sosSoundEnabled) {
                       CommunicationService().playSosSound();
                        }

                       // 🔹 Intentamos traer la app al frente
                      CommunicationService().bringToForeground();  

                       onSosActivated(); // ✅ Llamamos la función para actualizar la UI

                      // 📌 Enviar alerta SOS
                      CommunicationService().sendSosAlert(
                    //    BleData.deviceId,           // ID único del celular
                        device.remoteId.toString(), // MAC address del dispositivo BLE
                      );
                      showPanicAlert(context, device.remoteId.toString());
                      // 📞 Llamada automática si está activada en la configuración
                      if (BleData.autoCall) {
                        Future.delayed(const Duration(seconds: 1), () {
                          CommunicationService().callSosNumber();
                        });
                      }
                    }
                    panicTimer = null;
                  });
                } else if (value[4] == 0) {
                  // Botón soltado
                  print("Botón soltado");
                  if (panicTimer != null && panicTimer!.isActive) {
                    panicTimer!.cancel();
                  }
                  buttonPressed = false;
                  panicTimer = null;
                }
              }
            });
          }
        }
      }
    }
  } catch (e) {
    print("Error en discoverServices: $e");
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