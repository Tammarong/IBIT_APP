import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('official room catalog includes every named ITD room once', () async {
    final raw = await rootBundle.loadString('assets/rooms/itd_catalog.json');
    final rooms = (jsonDecode(raw) as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    expect(rooms.length, 18);
    expect(rooms.map((r) => r['id']).toSet().length, 18);
    expect(rooms.where((r) => r['category'] == 'classroom').length, 9);
    expect(rooms.where((r) => r['category'] == 'computer').length, 4);
    expect(rooms.where((r) => r['bookingEnabled'] == true).length, 13);
    for (final room in rooms) {
      expect(room['name'], contains(room['id']));
      expect(room['officialName'], contains(room['id']));
      expect(room['floor'], int.parse((room['id'] as String)[0]));
      expect(
        Uri.parse(room['imageUrl'] as String).host,
        'www.itd.kmutnb.ac.th',
      );
      expect(
        Uri.parse(room['sourceUrl'] as String).host,
        'www.itd.kmutnb.ac.th',
      );
    }
  });
}
