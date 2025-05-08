// File: lib/Testing.dart
import 'package:flutter_test/flutter_test.dart';
import 'DBConnection.dart';

void main() {


  test('Check if login returns "essam"', () async {
    final result = await DBConnection.logInByID(1, '11');
    expect(result?['UName'], equals('essam'));
  });

  test('addMap successfully adds a map', () async {
    final success = await DBConnection.addMap(
      UID: 1,
      MName: 'Jeddah Park',
      MCity: 'JED',
      MType: 'Park',
      MLocationURL: 'https://maps.example.com/central-park',
    );
    expect(success, isTrue);
  });

  
}