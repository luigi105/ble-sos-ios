import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'ios_permission_guide.dart';

class PermissionGuidePage extends StatefulWidget {
  const PermissionGuidePage({super.key});

  @override
  PermissionGuidePageState createState() => PermissionGuidePageState();
}

class PermissionGuidePageState extends State<PermissionGuidePage> {
  bool locationAlwaysGranted = false;
  bool phoneGranted = false;
  bool isChecking = false;

  @override
  void initState() {
    super.initState();
    checkPermissions();
  }

  Future<void> checkPermissions() async {
    setState(() => isChecking = true);
    
    locationAlwaysGranted = await Permission.locationAlways.isGranted;
    phoneGranted = await Permission.phone.isGranted;
    
    setState(() => isChecking = false);
  }

  Future<void> requestLocationAlways() async {
    setState(() => isChecking = true);
    
    // Explicar al usuario por qué necesitamos este permiso
    bool shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permiso de Ubicación"),
        content: const Text(
          "Para funcionar correctamente en segundo plano, esta app necesita "
          "acceso a la ubicación 'Todo el tiempo'.\n\n"
          "Esto permite:\n"
          "• Enviar tu ubicación cuando la app esté minimizada\n"
          "• Funcionar como dispositivo de emergencia 24/7\n\n"
          "¿Quieres configurar este permiso ahora?"
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
      await Permission.locationAlways.request();
      await checkPermissions();
    }
    
    setState(() => isChecking = false);
  }

  Future<void> requestPhone() async {
    setState(() => isChecking = true);
    
    // Explicar al usuario por qué necesitamos este permiso
    bool shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permiso de Llamadas"),
        content: const Text(
          "Para realizar llamadas de emergencia automáticas, esta app necesita "
          "permiso para hacer llamadas telefónicas.\n\n"
          "Esto permite:\n"
          "• Llamar automáticamente al número SOS configurado\n"
          "• Funcionar como sistema de pánico completo\n\n"
          "¿Quieres configurar este permiso ahora?"
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
      await Permission.phone.request();
      await checkPermissions();
    }
    
    setState(() => isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    bool allPermissionsGranted = locationAlwaysGranted && phoneGranted;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configuración de Permisos", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: allPermissionsGranted ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: allPermissionsGranted ? Colors.green : Colors.orange,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    allPermissionsGranted ? Icons.check_circle : Icons.warning,
                    color: allPermissionsGranted ? Colors.green : Colors.orange,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    allPermissionsGranted 
                      ? "¡Todos los permisos configurados!"
                      : "Permisos adicionales necesarios",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: allPermissionsGranted ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    allPermissionsGranted
                      ? "Tu app está lista para funcionar completamente"
                      : "Algunos permisos necesitan configuración manual",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: allPermissionsGranted ? Colors.green.shade600 : Colors.orange.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Lista de permisos
            if (isChecking)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Permiso de ubicación siempre
              _buildPermissionTile(
                title: "Ubicación en segundo plano",
                description: "Permite enviar ubicación cuando la app está minimizada",
                icon: Icons.location_on,
                isGranted: locationAlwaysGranted,
                onTap: locationAlwaysGranted ? null : requestLocationAlways,
              ),
              
              const SizedBox(height: 16),
              
              // Permiso de llamadas
              _buildPermissionTile(
                title: "Llamadas telefónicas",
                description: "Permite realizar llamadas SOS automáticas",
                icon: Icons.phone,
                isGranted: phoneGranted,
                onTap: phoneGranted ? null : requestPhone,
              ),
            ],
            
            const Spacer(),
            
            // Botón de continuar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: allPermissionsGranted ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  allPermissionsGranted ? "Continuar" : "Configurar más tarde",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            
            if (!allPermissionsGranted) ...[
              const SizedBox(height: 8),
              Text(
                "Nota: Puedes configurar estos permisos más tarde desde Configuración",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String description,
    required IconData icon,
    required bool isGranted,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isGranted ? Colors.green : Colors.orange,
          size: 32,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
        trailing: isGranted
          ? const Icon(Icons.check_circle, color: Colors.green)
          : TextButton(
              onPressed: onTap,
              child: const Text("Configurar"),
            ),
      ),
    );
  }
}