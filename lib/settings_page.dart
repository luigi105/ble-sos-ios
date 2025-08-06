import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'ble_data.dart';
import 'coms.dart';
import 'permission_guide.dart';
import 'ios_permission_guide.dart';
import 'ios_platform_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  TextEditingController phoneController = TextEditingController();
  TextEditingController macAddressController = TextEditingController();

  bool conBotonChecked = BleData.conBoton == 1;
  bool autoCallChecked = false; 
  bool sosSoundChecked = BleData.sosSoundEnabled;
  bool sosNotificationChecked = true;
  bool bleNotificationsChecked = true;
  final CommunicationService coms = CommunicationService();
  bool _isMounted = false;
  int nuevoValorBoton = BleData.conBoton;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    phoneController.text = "";
    macAddressController.text = "";
    autoCallChecked = BleData.autoCall;
    sosSoundChecked = BleData.sosSoundEnabled;
    sosNotificationChecked = BleData.sosNotificationEnabled;
    bleNotificationsChecked = BleData.bleNotificationsEnabled;
  }

  @override
  void dispose() {
    _isMounted = false;
    phoneController.dispose();
    macAddressController.dispose();
    super.dispose();
  }

  void _mostrarDialogoCambioImei() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Estás seguro?"),
        content: const Text("¿Estás seguro que quieres cambiar el IMEI? Esto restablecerá la configuración."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cambiarImei();
            },
            child: const Text("Aceptar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _cambiarImei() async {
    await BleData.setImei("UNKNOWN_IMEI");
    await BleData.setMacAddress("N/A");
    await BleData.setConBoton(0);
    BleData.restartApp();
  }

  Future<void> _guardarMacAddress() async {
    String nuevoMacAddress = macAddressController.text.trim();
    if (nuevoMacAddress.isNotEmpty && nuevoMacAddress != BleData.macAddress) {
      bool macActualizado = await coms.updateMacAddress(nuevoMacAddress);
      if (macActualizado) {
        await BleData.setMacAddress(nuevoMacAddress);
        if (_isMounted) {
          setState(() {});
        }
        _mostrarDialogoReinicio();
      }
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    resizeToAvoidBottomInset: true,
    appBar: AppBar(
      title: Text(
        Platform.isIOS ? "Configuración iOS" : "🤖 Configuración",
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.green, // ✅ CAMBIO: Verde consistente
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ CAMBIO MAYOR: Sección de permisos MOVIDA ARRIBA (antes de IMEI)
          Text(
            Platform.isIOS ? "Permisos para App SOS" : "Permisos del Sistema", 
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: Platform.isIOS ? Colors.blue.shade700 : Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 12),
          
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: Icon(
                Platform.isIOS ? Icons.settings_applications : Icons.security,
                color: Platform.isIOS ? Colors.blue : Colors.green,
                size: 32,
              ),
              title: Text(
                Platform.isIOS ? "Permisos para App SOS" : "Permisos del Sistema", // ✅ CAMBIO: Nuevo título
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                Platform.isIOS
                  ? "• Ubicación siempre\n• Bluetooth en background\n• Notificaciones críticas" // ✅ CAMBIO: Descripción actualizada
                  : "• Ubicación siempre\n• Bluetooth scan/connect\n• Llamadas telefónicas\n• Optimización de batería",
              ),
              trailing: ElevatedButton(
                onPressed: () {
                  if (Platform.isIOS) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const IOSPermissionGuidePage()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PermissionGuidePage()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  side: BorderSide(
                    color: Platform.isIOS ? Colors.blue : Colors.grey, 
                    width: 1,
                  ),
                  backgroundColor: Colors.white, // ✅ CAMBIO: Fondo blanco
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(
                  "Permisos", // ✅ CAMBIO: Nuevo texto del botón
                  style: TextStyle(
                    color: Platform.isIOS ? Colors.blue.shade700 : Colors.black,
                  ),
                ),
              ),
            ),
          ),
          
          _buildDivider(),
          
          _buildConfigRowImei(),
          _buildDivider(),
          
          // MAC ADDRESS - Solo mostrar si conBoton == 1
          if (BleData.conBoton == 1) ...[
            _buildConfigRow("MacAddress BLE:", BleData.macAddress, macAddressController, "Ingresar nuevo MacAddress"),
            _buildSaveButton("Guardar MacAddress", _guardarMacAddress),
            _buildDivider(),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.bluetooth_disabled, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "MacAddress BLE: Deshabilitado (solo ubicación GPS)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildDivider(),
          ],
          
          _buildConfigRow("Teléfono SOS:", BleData.sosNumber, phoneController, "Ingresar nuevo Teléfono SOS"),
          _buildSaveButton("Actualizar Teléfono SOS", _actualizarTelefonoSOS),
          _buildDivider(),
          
          // SECCIÓN MEJORADA: Modo de operación con descripciones
          Text(
            "Modo de Operación", 
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: Platform.isIOS ? Colors.blue.shade700 : Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 8),
          
          // Opción 1: Con Bluetooth
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: nuevoValorBoton == 1 
                  ? (Platform.isIOS ? Colors.blue : Colors.green)
                  : Colors.grey.shade300,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
              color: nuevoValorBoton == 1 
                ? (Platform.isIOS ? Colors.blue.shade50 : Colors.green.shade50)
                : Colors.white,
            ),
            child: RadioListTile<int>(
              title: Row(
                children: [
                  Icon(
                    Icons.bluetooth,
                    color: nuevoValorBoton == 1 
                      ? (Platform.isIOS ? Colors.blue : Colors.green)
                      : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Con Botón Bluetooth",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              subtitle: Text(
                Platform.isIOS
                  ? "• Reconexión automática por iOS\n• Batería optimizada\n• Ubicación en cambios significativos"
                  : "• Monitoreo continuo BLE\n• Reconexión agresiva\n• Ubicación cada 90 segundos",
                style: const TextStyle(fontSize: 12),
              ),
              value: 1,
              groupValue: nuevoValorBoton,
              onChanged: (value) {
                setState(() {
                  nuevoValorBoton = value!;
                });
              },
              activeColor: Platform.isIOS ? Colors.blue : Colors.green,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Opción 2: Solo ubicación
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: nuevoValorBoton == 2 
                  ? (Platform.isIOS ? Colors.blue : Colors.green)
                  : Colors.grey.shade300,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
              color: nuevoValorBoton == 2 
                ? (Platform.isIOS ? Colors.blue.shade50 : Colors.green.shade50)
                : Colors.white,
            ),
            child: RadioListTile<int>(
              title: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: nuevoValorBoton == 2 
                      ? (Platform.isIOS ? Colors.blue : Colors.green)
                      : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Solo Ubicación GPS",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              subtitle: Text(
                Platform.isIOS
                  ? "• Sin dispositivo BLE\n• Botón SOS manual en app\n• Máxima eficiencia de batería"
                  : "• Sin dispositivo BLE\n• Botón SOS manual en app\n• Solo envío de ubicación",
                style: const TextStyle(fontSize: 12),
              ),
              value: 2,
              groupValue: nuevoValorBoton,
              onChanged: (value) {
                setState(() {
                  nuevoValorBoton = value!;
                });
              },
              activeColor: Platform.isIOS ? Colors.blue : Colors.green,
            ),
          ),
          
          const SizedBox(height: 16),
          _buildSaveButton("Guardar Modo de Operación", _guardarConfigBotonBluetooth),
          _buildDivider(),
          
          // SECCIÓN CONFIGURACIONES CON DESCRIPCIONES ESPECÍFICAS
          Text(
            "Configuraciones de Emergencia", 
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: Platform.isIOS ? Colors.blue.shade700 : Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 12),
          
          // Llamado Automático
          _buildConfigSwitch(
            title: "Llamado Automático",
            subtitle: Platform.isIOS 
              ? "Llamar automáticamente durante los 30 segundos de emergencia iOS"
              : "Llamar automáticamente al activar SOS",
            icon: Icons.phone,
            value: autoCallChecked,
            onChanged: _actualizarLlamadoAutomatico,
          ),
          
          _buildDivider(),
          
          // Sonido SOS
          _buildConfigSwitch(
            title: "Sonido de Alerta SOS",
            subtitle: "Reproducir sonido al activar emergencia",
            icon: Icons.volume_up,
            value: sosSoundChecked,
            onChanged: _actualizarSonidoSos,
          ),
          
          _buildDivider(),
          
          // Notificaciones SOS
          _buildConfigSwitch(
            title: "Notificación SOS",
            subtitle: Platform.isIOS
              ? "Notificaciones críticas de emergencia en iOS"
              : "Traer app al frente durante SOS",
            icon: Icons.notification_important,
            value: sosNotificationChecked,
            onChanged: _actualizarNotificacionSos,
          ),
          
          _buildDivider(),
          
          // Notificaciones de Conexión
          _buildConfigSwitch(
            title: "Notificaciones de Estado",
            subtitle: Platform.isIOS
              ? "Estado de BLE y ubicación (configurado automáticamente por iOS)"
              : "Notificaciones de conexión BLE y ubicación",
            icon: Icons.notifications,
            value: bleNotificationsChecked,
            onChanged: _actualizarNotificacionesConexion,
          ),
          
          _buildDivider(),
          
          // ✅ INFORMACIÓN ADICIONAL ESPECÍFICA POR PLATAFORMA
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Platform.isIOS ? Colors.blue.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Platform.isIOS ? Colors.blue.shade200 : Colors.green.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info,
                      color: Platform.isIOS ? Colors.blue.shade700 : Colors.green.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Platform.isIOS ? "Optimizaciones iOS:" : "Características Android:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Platform.isIOS ? Colors.blue.shade700 : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (Platform.isIOS) ...[
                  const Text("• 🔄 Reconexión BLE automática por Apple"),
                  const Text("• 📍 Ubicación solo en cambios significativos (>100m)"),
                  const Text("• 🚨 SOS garantizado 30 segundos de ejecución"),
                  const Text("• 🛡️ Privacidad optimizada por iOS"),
                ] else ...[
                  const Text("• 🔋 Control total sobre optimizaciones"),
                  const Text("• 📡 Monitoreo continuo cada 90 segundos"),
                  const Text("• 🔄 Reconexión agresiva personalizable"),
                  const Text("• 💓 Sistema heartbeat para supervivencia"),
                  const Text("• 🎛️ Configuraciones avanzadas disponibles"),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildConfigRowImei() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("IMEI actual:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Row(
          children: [
            Text(BleData.imei, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _mostrarDialogoCambioImei,
              style: ElevatedButton.styleFrom(
                side: BorderSide(
                  color: Platform.isIOS ? Colors.blue : Colors.grey, 
                  width: 1,
                ),
                backgroundColor: Colors.white, // ✅ CAMBIO: Fondo blanco
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(
                "Cambiar IMEI",
                style: TextStyle(
                  color: Platform.isIOS ? Colors.blue.shade700 : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfigRow(String label, String value, TextEditingController controller, String hintText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderSide: BorderSide(
                color: Platform.isIOS ? Colors.blue : Colors.green,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Platform.isIOS ? Colors.blue : Colors.green,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSaveButton(String label, Function() onPressed) {
    return Center(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          side: BorderSide(
            color: Platform.isIOS ? Colors.blue : Colors.grey, 
            width: 1,
          ),
          backgroundColor: Colors.white, // ✅ CAMBIO: Fondo blanco
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Platform.isIOS ? Colors.blue.shade700 : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 18),
      height: 2,
      color: Platform.isIOS ? Colors.blue.shade200 : Colors.green.shade200,
      width: double.infinity,
    );
  }

  Widget _buildConfigSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SwitchListTile(
        secondary: Icon(
          icon,
          color: value 
            ? (Platform.isIOS ? Colors.blue : Colors.green)
            : Colors.grey,
          size: 28,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Platform.isIOS ? Colors.blue : Colors.green,
        activeTrackColor: Platform.isIOS ? Colors.blue.shade200 : Colors.green.shade200,
      ),
    );
  }

  Future<void> _guardarConfigBotonBluetooth() async {
    await BleData.setConBoton(nuevoValorBoton);
    if (_isMounted) {
      setState(() {});
    }
    _mostrarDialogoReinicio();
  }

  void _mostrarDialogoReinicio() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          Platform.isIOS ? "🍎 Reiniciando iOS" : "🤖 Reiniciando Android",
        ),
        content: Text(
          Platform.isIOS
            ? "Aplicando configuración optimizada para iOS..."
            : "Aplicando cambios...",
        ),
        backgroundColor: Platform.isIOS ? Colors.blue.shade50 : Colors.green.shade50,
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      BleData.restartApp();
    });
  }

  Future<void> _actualizarTelefonoSOS() async {
    String nuevoTelefono = phoneController.text.trim();
    if (nuevoTelefono.isNotEmpty && nuevoTelefono != BleData.sosNumber) {
      bool telefonoActualizado = await coms.updateSosNumber(nuevoTelefono);
      if (telefonoActualizado) {
        await BleData.setSosNumber(nuevoTelefono);
        if (_isMounted) setState(() {});
      }
    }
  }

  Future<void> _actualizarLlamadoAutomatico(bool value) async {
    await BleData.setAutoCall(value);
    if (_isMounted) {
      setState(() {
        autoCallChecked = value;
      });
    }
  }

  Future<void> _actualizarSonidoSos(bool value) async {
    await BleData.setSosSoundEnabled(value);
    if (_isMounted) {
      setState(() {
        sosSoundChecked = value;
      });
    }
  }

  Future<void> _actualizarNotificacionSos(bool value) async {
    await BleData.setSosNotificationEnabled(value);
    if (_isMounted) {
      setState(() {
        sosNotificationChecked = value;
      });
    }
  }
  
  Future<void> _actualizarNotificacionesConexion(bool value) async {
    await BleData.setBleNotificationsEnabled(value);
    if (_isMounted) {
      setState(() {
        bleNotificationsChecked = value;
      });
    }
  }
}