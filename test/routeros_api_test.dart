import 'package:test/test.dart';

int encodeLength(int length, List<int> target) {
  if (length < 0x80) {
    target.add(length);
    return 1;
  } else if (length < 0x4000) {
    length |= 0x8000;
    target.add((length >> 8) & 0xFF);
    target.add(length & 0xFF);
    return 2;
  } else if (length < 0x200000) {
    length |= 0xC00000;
    target.add((length >> 16) & 0xFF);
    target.add((length >> 8) & 0xFF);
    target.add(length & 0xFF);
    return 3;
  } else if (length < 0x10000000) {
    length |= 0xE0000000;
    target.add((length >> 24) & 0xFF);
    target.add((length >> 16) & 0xFF);
    target.add((length >> 8) & 0xFF);
    target.add(length & 0xFF);
    return 4;
  } else {
    target.add(0xF0);
    target.add((length >> 24) & 0xFF);
    target.add((length >> 16) & 0xFF);
    target.add((length >> 8) & 0xFF);
    target.add(length & 0xFF);
    return 5;
  }
}

int decodeLength(List<int> bytes) {
  int b1 = bytes[0];
  if ((b1 & 0x80) == 0) {
    return b1;
  } else if ((b1 & 0xC0) == 0x80) {
    int b2 = bytes[1];
    return ((b1 & 0x3F) << 8) | b2;
  } else if ((b1 & 0xE0) == 0xC0) {
    int b2 = bytes[1];
    int b3 = bytes[2];
    return ((b1 & 0x1F) << 16) | (b2 << 8) | b3;
  } else if ((b1 & 0xF0) == 0xE0) {
    int b2 = bytes[1];
    int b3 = bytes[2];
    int b4 = bytes[3];
    return ((b1 & 0x0F) << 24) | (b2 << 16) | (b3 << 8) | b4;
  } else if ((b1 & 0xF8) == 0xF0) {
    int b2 = bytes[1];
    int b3 = bytes[2];
    int b4 = bytes[3];
    int b5 = bytes[4];
    return (b2 << 24) | (b3 << 16) | (b4 << 8) | b5;
  }
  return 0;
}

void main() {
  group('RouterOS Length Encoding', () {
    test('encode/decode 1 byte length', () {
      final buffer = <int>[];
      encodeLength(10, buffer);
      expect(buffer, [10]);
      expect(decodeLength(buffer), 10);
    });

    test('encode/decode 2 byte length', () {
      final buffer = <int>[];
      encodeLength(200, buffer);
      expect(buffer, [0x80 | (200 >> 8), 200 & 0xFF]);
      expect(decodeLength(buffer), 200);
    });

    test('encode/decode edge cases', () {
      final testValues = [
        0,
        127,
        128,
        16383,
        16384,
        2097151,
        2097152,
        268435455
      ];
      for (var val in testValues) {
        final buffer = <int>[];
        encodeLength(val, buffer);
        expect(decodeLength(buffer), val, reason: 'Failed for value $val');
      }
    });
  });
}
