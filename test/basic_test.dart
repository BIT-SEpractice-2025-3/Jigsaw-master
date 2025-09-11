import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Basic Tests', () {
    test('String test', () {
      const string = 'Hello, world!';
      expect(string.length, 13);
      expect(string.startsWith('Hello'), true);
    });

    test('Number test', () {
      const number = 42;
      expect(number, 42);
      expect(number.isEven, true);
    });

    test('List test', () {
      final list = [1, 2, 3, 4, 5];
      expect(list.length, 5);
      expect(list.first, 1);
      expect(list.last, 5);
    });
  });
}
