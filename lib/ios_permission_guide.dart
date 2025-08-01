
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class IOSPermissionGuidePage extends StatefulWidget {
  const IOSPermissionGuidePage({super.key});

  @override
  IOSPermissionGuidePageState createState() => IOSPermissionGuidePageState();
}

class IOSPermissionGuidePageState extends State<IOSPermissionGuidePage> {
  bool locationAlwaysGranted = false;
  bool bluetoothGranted = false;
  bool notificationsGranted = false;
  bool isChecking = false;

  @override
  void initState() {
    super.initState();
    checkPermissions();
  }

  Future<void> checkPermissions() async {
    setState(() => isChecking = true);
    
    locationAlwaysGranted = await Permission.locationAlways.isGranted;
    bluetoothGranted = await Permission.bluetooth.isGranted;
    notificationsGranted = await Permission.notification.isGranted;
    
    setState(() => isChecking = false);
  }

 Future<void> requestLocationAlways() async {
  setState(() => isChecking = true);
  
  try {
    print("📍 iOS: Solicitando permisos de ubicación...");
    
    // Mostrar diálogo explicativo
    bool shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("📍 Ubicación Siempre"),
        content: const Text(
          "Para iOS, necesitamos acceso 'Siempre' a ubicación:\n\n"
          "• 🚨 Funciona para emergencias 24/7\n"
          "• 📱 Envía ubicación solo en cambios significativos\n"
          "• 🔋 Optimizado por Apple para batería\n"
          "• 🛡️ Privacidad protegida por iOS\n\n"
          "iOS solo enviará ubicación cuando te muevas >100 metros."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Más tarde"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Configurar", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (shouldRequest) {
      print("📍 Usuario aceptó - solicitando permisos...");
      
      // En iOS, primero solicitar "when in use", luego "always"
      PermissionStatus whenInUseStatus = await Permission.locationWhenInUse.request();
      print("📍 When in use result: $whenInUseStatus");
      
      if (whenInUseStatus.isGranted) {
        PermissionStatus alwaysStatus = await Permission.locationAlways.request();
        print("📍 Always result: $alwaysStatus");
      }
      
      await checkPermissions();
    } else {
      print("📍 Usuario canceló solicitud de ubicación");
    }
    
  } catch (e) {
    print("❌ Error solicitando ubicación: $e");
  }
  
  setState(() => isChecking = false);
}

  
Future<void> requestBluetooth() async {
  setState(() => isChecking = true);
  
  try {
    print("🔵 iOS: Solicitando permisos de Bluetooth...");
    
    bool shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🔵 Bluetooth"),
        content: const Text(
          "Para iOS, Bluetooth es esencial:\n\n"
          "• 🔗 Conexión automática con dispositivo SOS\n"
          "• 🔄 iOS maneja reconexión automáticamente\n"
          "• ⏰ Funciona incluso con app cerrada\n"
          "• 🚨 Respuesta inmediata a botón de pánico\n\n"
          "iOS garantiza funcionamiento en background."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Más tarde"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Configurar", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (shouldRequest) {
      print("🔵 Usuario aceptó - solicitando Bluetooth...");
      PermissionStatus bluetoothStatus = await Permission.bluetooth.request();
      print("🔵 Bluetooth result: $bluetoothStatus");
      
      await checkPermissions();
    } else {
      print("🔵 Usuario canceló solicitud de Bluetooth");
    }
    
  } catch (e) {
    print("❌ Error solicitando Bluetooth: $e");
  }
  
  setState(() => isChecking = false);
}


 Future<void> requestNotifications() async {
  setState(() => isChecking = true);
  
  try {
    print("🔔 iOS: Solicitando permisos de notificaciones...");
    
    bool shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🔔 Notificaciones"),
        content: const Text(
          "Para emergencias críticas:\n\n"
          "• 🚨 Alertas SOS de alta prioridad\n"
          "• 📍 Confirmación de ubicación enviada\n"
          "• 🔵 Estado de conexión BLE\n"
          "• ⚠️ Notificaciones de emergencia\n\n"
          "Configuradas como 'Críticas' en iOS."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Más tarde"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Configurar", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (shouldRequest) {
      print("🔔 Usuario aceptó - solicitando notificaciones...");
      PermissionStatus notificationStatus = await Permission.notification.request();
      print("🔔 Notification result: $notificationStatus");
      
      await checkPermissions();
    } else {
      print("🔔 Usuario canceló solicitud de notificaciones");
    }
    
  } catch (e) {
    print("❌ Error solicitando notificaciones: $e");
  }
  
  setState(() => isChecking = false);
}

@override
Widget build(BuildContext context) {
  bool allPermissionsGranted = locationAlwaysGranted && bluetoothGranted && notificationsGranted;
  
  return Scaffold(
    appBar: AppBar(
      title: const Text("🍎 Configuración iOS", style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.blue, // Azul para iOS
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: SafeArea(
      child: SingleChildScrollView( // ✅ CRÍTICO: Permite scroll
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado específico iOS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12), // ✅ REDUCIDO padding
              decoration: BoxDecoration(
                color: allPermissionsGranted ? Colors.blue.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: allPermissionsGranted ? Colors.blue : Colors.orange,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    allPermissionsGranted ? Icons.phone_iphone : Icons.warning,
                    color: allPermissionsGranted ? Colors.blue : Colors.orange,
                    size: 40, // ✅ REDUCIDO tamaño
                  ),
                  const SizedBox(height: 6), // ✅ REDUCIDO espacio
                  Text(
                    allPermissionsGranted 
                      ? "¡iOS configurado correctamente!"
                      : "Configuración iOS pendiente",
                    style: TextStyle(
                      fontSize: 16, // ✅ REDUCIDO font
                      fontWeight: FontWeight.bold,
                      color: allPermissionsGranted ? Colors.blue.shade700 : Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    allPermissionsGranted
                      ? "Tu dispositivo iOS funcionará de manera óptima"
                      : "iOS necesita configuraciones específicas",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12, // ✅ REDUCIDO font
                      color: allPermissionsGranted ? Colors.blue.shade600 : Colors.orange.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16), // ✅ REDUCIDO espacio
            
            // Información específica iOS
            Container(
              padding: const EdgeInsets.all(10), // ✅ REDUCIDO padding
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700, size: 16), // ✅ REDUCIDO
                      const SizedBox(width: 6),
                      Text(
                        "Ventajas iOS:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14, // ✅ REDUCIDO font
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text("• 🔋 Batería dura 2-3 días", style: TextStyle(fontSize: 12)),
                  const Text("• 🔄 Reconexión BLE automática", style: TextStyle(fontSize: 12)),
                  const Text("• 📍 Ubicación en cambios >100m", style: TextStyle(fontSize: 12)),
                  const Text("• 🚨 SOS garantizado 30 segundos", style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Lista de permisos específicos iOS
            if (isChecking)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildIOSPermissionTile(
                title: "Ubicación Siempre",
                description: "Para emergencias 24/7",
                icon: Icons.location_on,
                isGranted: locationAlwaysGranted,
                onTap: locationAlwaysGranted ? null : requestLocationAlways,
                priority: "Crítico",
              ),
              
              const SizedBox(height: 12), // ✅ REDUCIDO espacio
              
              _buildIOSPermissionTile(
                title: "Bluetooth",
                description: "Conexión automática con dispositivo SOS",
                icon: Icons.bluetooth,
                isGranted: bluetoothGranted,
                onTap: bluetoothGranted ? null : requestBluetooth,
                priority: "Esencial",
              ),
              
              const SizedBox(height: 12),
              
              _buildIOSPermissionTile(
                title: "Notificaciones",
                description: "Alertas críticas de emergencia",
                icon: Icons.notifications,
                isGranted: notificationsGranted,
                onTap: notificationsGranted ? null : requestNotifications,
                priority: "Importante",
              ),
            ],
            
            const SizedBox(height: 20), // ✅ ESPACIO FINAL
            
            // Botón de continuar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: allPermissionsGranted ? Colors.blue : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14), // ✅ REDUCIDO padding
                ),
                child: Text(
                  allPermissionsGranted ? "Continuar con iOS" : "Configurar más tarde",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), // ✅ REDUCIDO font
                ),
              ),
            ),
            
            if (!allPermissionsGranted) ...[
              const SizedBox(height: 8),
              Text(
                "💡 iOS funciona mejor con todas las configuraciones",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600), // ✅ REDUCIDO font
              ),
            ],
            
            // ✅ ESPACIO FINAL EXTRA para asegurar scroll
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  );
}


  Widget _buildIOSPermissionTile({
  required String title,
  required String description,
  required IconData icon,
  required bool isGranted,
  required String priority,
  VoidCallback? onTap,
}) {
  Color priorityColor = priority == "Crítico" 
      ? Colors.red 
      : priority == "Esencial" 
          ? Colors.orange 
          : Colors.blue;
  
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(8),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // ✅ REDUCIDO padding
      leading: Icon(
        icon,
        color: isGranted ? Colors.blue : priorityColor,
        size: 28, // ✅ REDUCIDO tamaño
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), // ✅ REDUCIDO font
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), // ✅ REDUCIDO padding
            decoration: BoxDecoration(
              color: priorityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: priorityColor.withOpacity(0.3)),
            ),
            child: Text(
              priority,
              style: TextStyle(
                fontSize: 9, // ✅ REDUCIDO font
                fontWeight: FontWeight.bold,
                color: priorityColor,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(description, style: const TextStyle(fontSize: 12)), // ✅ REDUCIDO font
      trailing: isGranted
        ? const Icon(Icons.check_circle, color: Colors.blue, size: 24) // ✅ REDUCIDO tamaño
        : TextButton(
            onPressed: onTap,
            child: const Text("Configurar", style: TextStyle(fontSize: 12)), // ✅ REDUCIDO font
          ),
    ),
  );
}
}