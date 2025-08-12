import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../lib/services/token_service.dart';

void main() {
  group('TokenService Tests', () {
    late TokenService tokenService;

    setUpAll(() async {
      // Load test environment
      await dotenv.load(fileName: '.env');
    });

    setUp(() {
      tokenService = TokenService();
    });

    test('should load production token server URL from environment', () {
      final url = tokenService.productionTokenServerUrl;
      expect(url, isNotNull);
      expect(url, equals('http://localhost:8080'));
    });

    test('should fetch connection details from production server', () async {
      // Skip if no production URL is set
      if (tokenService.productionTokenServerUrl == null) {
        markTestSkipped('Production token server URL not configured');
        return;
      }

      try {
        final details = await tokenService.fetchConnectionDetails(
          roomName: 'test-room-flutter',
          participantName: 'flutter-test-user',
        );

        expect(details.roomName, equals('test-room-flutter'));
        expect(details.participantName, equals('flutter-test-user'));
        expect(details.serverUrl, isNotEmpty);
        expect(details.participantToken, isNotEmpty);

        // Basic JWT validation (should have 3 parts separated by dots)
        expect(details.participantToken.split('.').length, equals(3));

        print('✅ Token generation successful!');
        print('Server URL: ${details.serverUrl}');
        print('Room: ${details.roomName}');
        print('Participant: ${details.participantName}');
        print('Token: ${details.participantToken.substring(0, 50)}...');
      } catch (e) {
        print('❌ Token generation failed: $e');
        fail('Token generation should not fail: $e');
      }
    });

    test('should handle token server errors gracefully', () async {
      // Test with invalid room name to trigger error handling
      try {
        await tokenService.fetchConnectionDetailsFromProduction(
          roomName: '', // Invalid empty room name
          participantName: 'test-user',
        );
        fail('Should have thrown an exception for invalid room name');
      } catch (e) {
        expect(e, isA<Exception>());
        print('✅ Error handling works correctly: $e');
      }
    });
  });
}
