import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:gbk_codec/gbk_codec.dart';

const int _kMaxSmi64 = (1 << 62) - 1;
const int _kMaxSmi32 = (1 << 30) - 1;
final int _maxSize = sizeOf<IntPtr>() == 8 ? _kMaxSmi64 : _kMaxSmi32;

class Gbk extends Struct {
  static int strlen(Pointer<Gbk> string) {
    final Pointer<Uint8> array = string.cast<Uint8>();
    final Uint8List nativeString = array.asTypedList(_maxSize);
    return nativeString.indexOf(0);
  }

  static String fromGbk(Pointer<Gbk> string, {int length}) {
    if (length != null) {
      RangeError.checkNotNegative(length, 'length');
    } else {
      length = strlen(string);
    }
    return gbkDecode(string.cast<Uint8>().asTypedList(length));
  }

  static String gbkDecode(List<int> input) {
    List<int> combined = new List<int>();
    int id = 0;
    while (id < input.length) {
      int charCode = input[id];
      id++;
      if (charCode < 0x80 || charCode > 0xffff || id == input.length) {
        combined.add(charCode);
      } else {
        charCode = (charCode << 8) + input[id];
        id++;
        combined.add(charCode);
      }
    }
    return gbk.decode(combined);
  }

  static Pointer<Gbk> toGbk(String string) {
    final units = gbk.encode(string);
    final departed = List<int>.empty(growable: true);
    for (int i in units) {
      String s = i.toRadixString(16);
      if (s.length <= 2) {
        departed.add(i);
      } else {
        departed.add(int.parse(s.substring(0, s.length - 2), radix: 16));
        departed.add(int.parse(s.substring(s.length - 2), radix: 16));
      }
    }
    final Pointer<Uint8> result = allocate<Uint8>(count: departed.length + 1);
    final Uint8List nativeString = result.asTypedList(departed.length + 1);
    nativeString.setAll(0, departed);
    nativeString[departed.length] = 0;
    return result.cast();
  }

  @override
  String toString() => fromGbk(addressOf);
}
