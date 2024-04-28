import 'package:http/http.dart' as http;
import 'dart:convert';
import 'notification_handler.dart';

class NgrokManager {
  static String ngrokUrl = '';

  static Future<void> fetchNgrokData() async {
    const apiUrl = 'https://api.ngrok.com/tunnels';
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization':
              'Bearer 2S8edfZVOrPgS1palig5QqUHgH0_4GkYGcRXzyLviUAxyRvyq',
          'Ngrok-Version': '2',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final tunnels = jsonResponse['tunnels'] as List<dynamic>;
        if (tunnels.isNotEmpty) {
          final tunnel = tunnels[0] as Map<String, dynamic>;
          final publicUrl = tunnel['public_url'] as String;

          // Use the NotificationHandler class to display the message
          NotificationHandler.showNotification(
              'Ngrok URL Fetched', 'apiBaseUrl updated to: $publicUrl');

          // Update the ngrokUrl
          ngrokUrl = publicUrl;
        } else {
          // Use the NotificationHandler class to display the message
          NotificationHandler.showNotification('No Ngrok Tunnel',
              'No tunnel is currently running, contact your administrator');
        }
      } else {
        // Use the NotificationHandler class to display the message
        NotificationHandler.showNotification(
            'Error', 'Could not initialize ngrok tunnel.');
      }
    } catch (e) {
      // Use the NotificationHandler class to display the error message
      NotificationHandler.showNotification(
          'Error', 'Could not fetch ngrok data: $e');
    }
  }
}
