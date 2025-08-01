import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'coms.dart';
import 'dart:async';
import 'ble_data.dart';
import 'dart:io';

bool buttonPressed = false;
Timer? panicTimer;

void connectToDevice(BluetoothDevice device, BuildContext context, Function discoverServicesCallback, Function triggerUpdateTimerCallback, Function onSosActivated) async {
  try {
    print("🔗 Intentando conectar con: ${device.remoteId}");

    if (Platform.isIOS) {
      print("🍎 === CONEXIÓN BLE ESPECÍFICA PARA iOS ===");
      
      try {
        // ✅ iOS: Estrategia más agresiva
        print("🔵 iOS: Conectando con autoConnect y timeout extendido...");
        
        await device.connect(
          autoConnect: true,
          timeout: const Duration(seconds: 45), // ✅ TIMEOUT MÁS LARGO para iOS
        );
        
        print("✅ iOS: Conexión inicial exitosa");
        
        // ✅ VERIFICAR estado inmediatamente
        BluetoothConnectionState currentState = await device.connectionState.first;
        print("🔍 iOS: Estado después de conectar: $currentState");
        
        if (currentState == BluetoothConnectionState.connected) {
          print("✅ iOS: Confirmado - dispositivo conectado");
          
          BleData.update(
            newMacAddress: device.remoteId.toString(),
            connectionStatus: true,
          );
          
          // ✅ INMEDIATAMENTE descubrir servicios
          await Future.delayed(Duration(seconds: 1));
          discoverServicesCallback(device, context, onSosActivated);
          triggerUpdateTimerCallback();
          
        } else {
          print("⚠️ iOS: Estado inesperado después de conectar: $currentState");
        }
        
      } catch (e) {
        print("❌ iOS: Error en conexión: $e");
        
        // ✅ RETRY específico para iOS
        print("🔄 iOS: Intentando reconexión inmediata...");
        try {
          await Future.delayed(Duration(seconds: 2));
          await device.connect(
            autoConnect: true,
            timeout: const Duration(seconds: 30),
          );
          print("✅ iOS: Reconexión exitosa");
        } catch (retryError) {
          print("❌ iOS: Falló reconexión: $retryError");
        }
      }
      
      // ✅ CONFIGURAR listener permanente para iOS
      device.connectionState.listen((state) {
        print("🔵 iOS BLE Estado cambió a: $state");
        
        if (state == BluetoothConnectionState.connected) {
          print("✅ iOS: BLE conectado - actualizando estado");
          BleData.update(
            newMacAddress: device.remoteId.toString(),
            connectionStatus: true,
          );
          BleData.saveConnectionState(true);
          
          // Re-configurar servicios si es necesario
          discoverServicesCallback(device, context, onSosActivated);
          
        } else if (state == BluetoothConnectionState.disconnected) {
          print("⚠️ iOS: BLE desconectado - autoConnect manejará reconexión");
          BleData.update(
            newMacAddress: device.remoteId.toString(),
            connectionStatus: false,
          );
          BleData.saveConnectionState(false);
          
          // iOS con autoConnect intentará reconectar automáticamente
        }
      });
      
    } else {
      // Android: código existente sin cambios
      // ... tu código Android actual ...
    }
    
  } catch (e) {
    print("❌ Error general al conectar: $e");
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