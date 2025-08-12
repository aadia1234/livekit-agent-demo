import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Data class representing the connection details needed to join a LiveKit room
/// This includes the server URL, room name, participant info, and auth token
class ConnectionDetails {
  final String serverUrl;
  final String roomName;
  final String participantName;
  final String participantToken;

  ConnectionDetails({
    required this.serverUrl,
    required this.roomName,
    required this.participantName,
    required this.participantToken,
  });

  factory ConnectionDetails.fromJson(Map<String, dynamic> json) {
    return ConnectionDetails(
      serverUrl: json['serverUrl'],
      roomName: json['roomName'],
      participantName: json['participantName'],
      participantToken: json['participantToken'],
    );
  }
}

/// An example service for fetching LiveKit authentication tokens
///
/// Production Configuration:
/// - Set your production token server URL in the `productionTokenServerUrl` field below
/// - Ensure your server has the /token endpoint that accepts POST requests with roomName and participantName
/// - Your server should return JSON with: serverUrl, roomName, participantName, participantToken
///
/// Development Options:
/// - Use LiveKit Cloud sandbox: Enable at https://cloud.livekit.io/projects/p_/sandbox/templates/token-server
/// - Use hardcoded token: Generate at https://docs.livekit.io/home/cli/cli-setup/#generate-access-token
///
/// See https://docs.livekit.io/home/get-started/authentication for more information
class TokenService {
  // PRODUCTION: Set your token server URL here or via environment variable
  String? get productionTokenServerUrl {
    // First check environment variable, then fallback to hardcoded value
    final envValue = dotenv.env['PRODUCTION_TOKEN_SERVER_URL'];
    if (envValue != null &&
        envValue.isNotEmpty &&
        envValue != 'https://your-domain.com') {
      return envValue.replaceAll('"', '');
    }
    // Return null if not set - this will fallback to other methods
    return null; // Set your production URL here: "https://your-domain.com"
  }

  // For hardcoded token usage (development only)
  final String? hardcodedServerUrl = null;
  final String? hardcodedToken = null;

  // Get the sandbox ID from environment variables
  String? get sandboxId {
    final value = dotenv.env['LIVEKIT_SANDBOX_ID'];
    debugPrint('LIVEKIT_SANDBOX_ID: $value');
    if (value != null) {
      // Remove unwanted double quotes if present
      return value.replaceAll('"', '');
    }
    return null;
  }

  // LiveKit Cloud sandbox API endpoint
  final String sandboxUrl =
      'https://cloud-api.livekit.io/api/sandbox/connection-details';

  /// Main method to get connection details
  /// Priority order: 1) Production server 2) Hardcoded credentials 3) Sandbox
  Future<ConnectionDetails> fetchConnectionDetails({
    required String roomName,
    required String participantName,
  }) async {
    // Try production server first
    if (productionTokenServerUrl != null) {
      try {
        return await fetchConnectionDetailsFromProduction(
          roomName: roomName,
          participantName: participantName,
        );
      } catch (e) {
        debugPrint('Production server failed, falling back: $e');
      }
    }

    // Fall back to hardcoded credentials
    final hardcodedDetails = fetchHardcodedConnectionDetails(
      roomName: roomName,
      participantName: participantName,
    );

    if (hardcodedDetails != null) {
      return hardcodedDetails;
    }

    // Finally try sandbox
    return await fetchConnectionDetailsFromSandbox(
      roomName: roomName,
      participantName: participantName,
    );
  }

  /// Fetch connection details from your production token server
  Future<ConnectionDetails> fetchConnectionDetailsFromProduction({
    required String roomName,
    required String participantName,
  }) async {
    if (productionTokenServerUrl == null) {
      throw Exception('Production token server URL is not set');
    }

    final uri = Uri.parse('$productionTokenServerUrl/token');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'roomName': roomName,
          'participantName': participantName,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final data = jsonDecode(response.body);
          debugPrint("Connection details from production server: $data");
          return ConnectionDetails.fromJson(data);
        } catch (e) {
          debugPrint(
              'Error parsing connection details from production server, response: ${response.body}');
          throw Exception(
              'Error parsing connection details from production server');
        }
      } else {
        debugPrint(
            'Error from production token server: ${response.statusCode}, response: ${response.body}');
        throw Exception('Error from production token server');
      }
    } catch (e) {
      debugPrint('Failed to connect to production token server: $e');
      throw Exception('Failed to connect to production token server');
    }
  }

  Future<ConnectionDetails> fetchConnectionDetailsFromSandbox({
    required String roomName,
    required String participantName,
  }) async {
    if (sandboxId == null) {
      throw Exception('Sandbox ID is not set');
    }

    final uri = Uri.parse(sandboxUrl).replace(queryParameters: {
      'roomName': roomName,
      'participantName': participantName,
    });

    try {
      final response = await http.post(
        uri,
        headers: {'X-Sandbox-ID': sandboxId!},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final data = jsonDecode(response.body);
          return ConnectionDetails.fromJson(data);
        } catch (e) {
          debugPrint(
              'Error parsing connection details from LiveKit Cloud sandbox, response: ${response.body}');
          throw Exception(
              'Error parsing connection details from LiveKit Cloud sandbox');
        }
      } else {
        debugPrint(
            'Error from LiveKit Cloud sandbox: ${response.statusCode}, response: ${response.body}');
        throw Exception('Error from LiveKit Cloud sandbox');
      }
    } catch (e) {
      debugPrint('Failed to connect to LiveKit Cloud sandbox: $e');
      throw Exception('Failed to connect to LiveKit Cloud sandbox');
    }
  }

  ConnectionDetails? fetchHardcodedConnectionDetails({
    required String roomName,
    required String participantName,
  }) {
    if (hardcodedServerUrl == null || hardcodedToken == null) {
      return null;
    }

    return ConnectionDetails(
      serverUrl: hardcodedServerUrl!,
      roomName: roomName,
      participantName: participantName,
      participantToken: hardcodedToken!,
    );
  }
}
