import 'package:http/http.dart' as http;

void main() async {
  try {
    print('Sending request with application/x-www-form-urlencoded...');
    final request = http.Request('POST', Uri.parse('https://script.google.com/macros/s/AKfycbyA1Uyqpnvbr0Wl1Ns7C01OBSobAxCyP7XcdRi9YwRq7aa-_cmBUry3dQ6NTSfgZKR-5g/exec'))
      ..followRedirects = false
      ..headers['Content-Type'] = 'application/x-www-form-urlencoded'
      ..bodyFields = {
        'name': 'Test Name',
        'email': 'test@test.com',
        'feedback': 'Test Feedback',
      };
    final client = http.Client();
    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    print('Status: ${response.statusCode}');
    print('Body length: ${response.body.length}');
    if (response.headers.containsKey('location')) {
      print('Location: ${response.headers['location']}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
