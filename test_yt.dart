void main() {
  final regex = RegExp(r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?|shorts)\/|.*[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})', caseSensitive: false);
  final links = [
    'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'https://youtu.be/dQw4w9WgXcQ',
    'https://youtube.com/shorts/dQw4w9WgXcQ?feature=share',
    'https://youtu.be/dQw4w9WgXcQ?si=test'
  ];
  for (var link in links) {
    final match = regex.firstMatch(link);
    print(': ');
  }
}
