import 'package:mysql_client/mysql_client.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class DBConnection {
  /*
  Sections Related to: 
  1 : Authentication & Aithorization
  2 : User
  3 : Map
  4 : Floor
  5 : POI
  6 : Viewing
  7 : Testing
  */
  static MySQLConnection? _connection;

  // Initialize the database connection
  static Future<void> initialize() async {
    try {
      _connection = await MySQLConnection.createConnection(
        // host: '10.24.121.70',
        // host: '192.168.1.14',
        // host: '192.168.236.1',
        // host: '192.168.8.122',
        host: 'localhost',
        //host: '192.168.100.39',
        // host: '127.0.0.1',

        port: 3306,
        userName: 'myphone',
        password: 'mymine?11112',
        databaseName: 'SyncMapDB',
        secure: true,
      );
      await _connection!.connect();
      print("DB Connected !");
    } catch (e) {
      print("Connection failed ${e}");
      rethrow;
    }
  }

  // Get the database connection
  static MySQLConnection? get connection => _connection;

// Close the database connection
  static Future<void> close() async {
    if (_connection != null) {
      await _connection!.close();
    }
  }

//
//
//
//  Section 1 :  Methods to check the authorization and authentication
//  Is user ..  Admin ?   Map Owner ?   Editable for POI ?
//  Delete User  -  Grant User Admin  -  Revoke User Admin

  // Check if the user is an admin
  static Future<bool> isUserAdmin(int userId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      // Execute the query to fetch the UIsAdmin field
      final result = await _connection!.execute(
        'SELECT UIsAdmin FROM User WHERE UID = :id',
        {'id': userId},
      );

      // Check if the user exists and retrieve the UIsAdmin value
      if (result.rows.isNotEmpty) {
        final isAdmin =
            int.tryParse(result.rows.first.assoc()['UIsAdmin'].toString());
        print('\n\n\n\n\n\n ${isAdmin.runtimeType} \n\n\n\n\n');
        return isAdmin == 1; // Return true if UIsAdmin is 1, otherwise false
      } else {
        return false; // User not found // essam
      }
    } catch (e) {
      print('Error checking admin status: $e');
      return false; // essam
    }
  }

  // Check if the user is the owner of the map
  static Future<bool> isUserMapOwner(int userId, int mapId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      // Execute the query to fetch the UID of the map owner
      final result = await _connection!.execute(
        'SELECT UID FROM Map WHERE MID = :mapId',
        {'mapId': mapId},
      );

      // Check if the map exists and retrieve the UID of the owner
      if (result.rows.isNotEmpty) {
        final ownerId =
            int.tryParse(result.rows.first.assoc()['UID'].toString());
        return ownerId ==
            userId; // Return true if the user is the owner, otherwise false
      } else {
        return false; // Map not found
      }
    } catch (e) {
      print('Error checking map ownership: $e');
      return false; // Return false on error
    }
  }

  // Check if the user can edit the POI
  static Future<bool> canUserEditPOI(int userId, int poiId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      // Step 1: Check if the user has access to the POI in the User_POI table
      final userPOIResult = await _connection!.execute(
        'SELECT UID FROM User_POI WHERE UID = :userId AND PID = :poiId',
        {'userId': userId, 'poiId': poiId},
      );

      if (userPOIResult.rows.isEmpty) {
        return false; // User does not have access to the POI
      }

      // Step 2: Check if the POI can be edited based on PEditDateMMYY
      final poiResult = await _connection!.execute(
        'SELECT PEditDateMMYY FROM POI WHERE PID = :poiId',
        {'poiId': poiId},
      );

      if (poiResult.rows.isNotEmpty) {
        final editDate = poiResult.rows.first.assoc()['PEditDateMMYY'];
        final currentDate = _getCurrentDateInFormat();

        // Compare the edit date with the current date
        return editDate == currentDate; // Return true if the dates match
      } else {
        return false; // POI not found
      }
    } catch (e) {
      print('Error checking POI edit permission: $e');
      return false; // Return false on error
    }
  }

// Delete User
  static Future<bool> deleteUser(int userId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'DELETE FROM User WHERE UID = :userId',
        {'userId': userId},
      );
      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

// Grant User Admin
  static Future<bool> grantAdmin(int userId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'UPDATE User SET UIsAdmin = 1 WHERE UID = :userId',
        {'userId': userId},
      );
      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error granting admin: $e');
      return false;
    }
  }

// Revoke User Admin
  static Future<bool> revokeAdmin(int userId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'UPDATE User SET UIsAdmin = 0 WHERE UID = :userId',
        {'userId': userId},
      );
      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error revoking admin: $e');
      return false;
    }
  }

//
//
//
//  Section 2 : User Related Methods
//    new account  -  Log in  -  get User name  -  edit ( name - pass - email)

// user create account
  static Future<int?> createAccount(
      String name, String email, String password) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    password = generate250CharHash(password);

    print(password);
    try {
      // Insert the user's data into the database
      await _connection!.execute(
        'INSERT INTO User (UName, UEmail, UHashPass) VALUES (:name, :email, :password)',
        {
          'name': name,
          'email': email,
          'password': password, // You may hash the password before storing it
        },
      );

      // Retrieve the newly created user's ID
      final result =
          await _connection!.execute('SELECT LAST_INSERT_ID() AS UserID');

      if (result.rows.isNotEmpty) {
        // Extract the user ID and cast it to an int
        final userId =
            int.tryParse(result.rows.first.assoc()['UserID'].toString());
        return userId; // Return the user's ID
      } else {
        return null; // No ID found
      }
    } catch (e) {
      print('Error during account creation: $e');
      return null; // Return null on error
    }
  }


// user log in
  static Future<Map<String, dynamic>?> logInByID (
      int ID, String password) async {
    if (_connection == null) {
      await initialize();
      // throw Exception('DB connection no initialized');
    }

    password = generate250CharHash(password);
    print(password);

    final result = await _connection!.execute(
      'SELECT * FROM User Where UID = :ID AND UHashPass= :password',
      {'ID': ID, 'password': password},
    );

    if (result.rows.isNotEmpty) {
      return result.rows.first.assoc();
    } else {
      return null;
    }
  }

// get user's name by ID
  static Future<String> fetchUserName(int userId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    final result = await _connection!.execute(
      'SELECT UName FROM User WHERE UID = :id',
      {'id': userId},
    );

    if (result.rows.isNotEmpty) {
      return result.rows.first.assoc()['UName'] ?? 'No name found';
    } else {
      return 'User not found';
    }
  }

// Change the user's name
  static Future<bool> changeName(int userId, String newName) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'UPDATE User SET UName = :newName WHERE UID = :userId',
        {'newName': newName, 'userId': userId},
      );

      final affectedRows = result.affectedRows.toInt(); // Convert to int
      return affectedRows > 0;
    } catch (e) {
      print('Error updating name: $e');
      return false;
    }
  }

// Change the user's password
  static Future<bool> changePass(int userId, String newPassword) async {
    print('\n\n\nEntering change pass\n\n\n');
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    newPassword = generate250CharHash(newPassword);

    try {
      final result = await _connection!.execute(
        'UPDATE User SET UHashPass = :newPassword WHERE UID = :userId',
        {'newPassword': newPassword, 'userId': userId},
      );

      final affectedRows = result.affectedRows.toInt(); // Convert to int
      return affectedRows > 0;
    } catch (e) {
      print('Error updating password: $e');
      return false;
    }
  }

// Change the user's email
  static Future<bool> changeEmail(int userId, String newEmail) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'UPDATE User SET UEmail = :newEmail WHERE UID = :userId',
        {'newEmail': newEmail, 'userId': userId},
      );

      final affectedRows = result.affectedRows.toInt(); // Convert to int
      return affectedRows > 0;
    } catch (e) {
      print('Error updating email: $e');
      return false;
    }
  }

//
//
//
//  Section 3 : Map Related Methods
//  Add map  -  Update ( name - city - type - location URL - owner? )  -  Delete Map

// Add Map
  static Future<bool> addMap({
    required int UID,
    required String MName,
    required String MCity,
    required String MType,
    required String MLocationURL,
  }) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      // Insert the map's data into the database
      final result = await _connection!.execute(
        'INSERT INTO Map (UID, MName, MCity, MType, MLocationURL, MImage) '
        'VALUES (:UID, :MName, :MCity, :MType, :MLocationURL, :MImage)',
        {
          'UID': UID,
          'MName': MName,
          'MCity': MCity,
          'MType': MType,
          'MLocationURL': MLocationURL,
          'MImage' : '',
        },
      );

      // Convert affectedRows to int before comparison
      final affectedRows = result.affectedRows.toInt();
      return affectedRows > 0;
    } catch (e) {
      print('Error during map creation: $e');
      return false; // Return false on error
    }
  }

  // Update Map Name
  static Future<bool> updateMapName(int mapId, String newName) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'UPDATE Map SET MName = :newName WHERE MID = :mapId',
        {'newName': newName, 'mapId': mapId},
      );

      // Check if the update was successful
      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error updating map name: $e');
      return false;
    }
  }

  // Update Map City
  static Future<bool> updateMapCity(int mapId, String newCity) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'UPDATE Map SET MCity = :newCity WHERE MID = :mapId',
        {'newCity': newCity, 'mapId': mapId},
      );

      // Check if the update was successful
      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error updating map city: $e');
      return false;
    }
  }

  // Update Map Type
  static Future<bool> updateMapType(int mapId, String newType) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'UPDATE Map SET MType = :newType WHERE MID = :mapId',
        {'newType': newType, 'mapId': mapId},
      );

      // Check if the update was successful
      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error updating map type: $e');
      return false;
    }
  }

  // Update Map Location URL
  static Future<bool> updateMapLocationURL(
      int mapId, String newLocationURL) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'UPDATE Map SET MLocationURL = :newLocationURL WHERE MID = :mapId',
        {'newLocationURL': newLocationURL, 'mapId': mapId},
      );

      // Check if the update was successful
      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error updating map location URL: $e');
      return false;
    }
  }

  // Update Map Owner (UID)
  static Future<bool> updateMapOwner(int mapId, int newOwnerId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'UPDATE Map SET UID = :newOwnerId WHERE MID = :mapId',
        {'newOwnerId': newOwnerId, 'mapId': mapId},
      );

      // Check if the update was successful
      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error updating map owner: $e');
      return false;
    }
  }

// Delete Map
  static Future<bool> deleteMap(int mapId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'DELETE FROM Map WHERE MID = :mapId',
        {'mapId': mapId},
      );
      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error deleting map: $e');
      return false;
    }
  }

//
//
//
//  Section 4 : Floor Related Methods
//  Add floor  -  Update( image -  Name )?  -  Delete Floor

// Add FLoor
  static Future<bool> addFloor(
      int mapId, String floorName, String imagePath) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'INSERT INTO Floor (MID, FName, FImage) VALUES (:mapId, :floorName, :imagePath)',
        {'mapId': mapId, 'floorName': floorName, 'imagePath': imagePath},
      );
      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error adding floor: $e');
      return false;
    }
  }

//  Update Floor Image
  static Future<bool> updateFloorImage(
      int floorId, int mapId, String newImagePath) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'UPDATE Floor SET FImage = :newImagePath WHERE FID = :floorId AND MID = :mapId',
        {
          'newImagePath': newImagePath,
          'floorId': floorId,
          'mapId': mapId,
        },
      );

      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error updating floor image: $e');
      return false;
    }
  }

//  Update Floor Name and Image Path
  static Future<bool> editFloorInfo({
    required int floorId,
    required int mapId,
    String? newFloorName,
    String? newImagePath,
  }) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      if (newFloorName != null) {
        await _connection!.execute(
          'UPDATE Floor SET FName = :newFloorName WHERE FID = :floorId AND MID = :mapId',
          {
            'newFloorName': newFloorName,
            'floorId': floorId,
            'mapId': mapId,
          },
        );
      }

      if (newImagePath != null) {
        await _connection!.execute(
          'UPDATE Floor SET FImage = :newImagePath WHERE FID = :floorId AND MID = :mapId',
          {
            'newImagePath': newImagePath,
            'floorId': floorId,
            'mapId': mapId,
          },
        );
      }

      return true;
    } catch (e) {
      print('Error updating floor info: $e');
      return false;
    }
  }

// Delete Floor
  static Future<bool> deleteFloor(int floorId, int mapId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'DELETE FROM Floor WHERE FID = :floorId AND MID = :mapId',
        {'floorId': floorId, 'mapId': mapId},
      );
      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error deleting floor: $e');
      return false;
    }
  }

//
//
//
//  Section 5 : POI Related Methods
//  Add POI  -  Update POI  -  Get POI to print  -  Get POI to Use  -  Delete POI
//  Check if User Can Edit POI ?   -   Grant User Edit POI   -   Revoke User Edit POI
//  Still Data ?  Current Date ?
//  Add POI
  static Future<int?> addPOI({
    required int fid,
    required int mid,
    required int px,
    required int py,
    required String pName,
    required int editMonth, // 1-12
    required int editYear, // Can be 2-digit or 4-digit
    String? pDescription,
    String? pIconName,
  }) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    // Validate month (1-12)
    if (editMonth < 1 || editMonth > 12) {
      throw Exception('Invalid month (must be 1-12)');
    }

    try {
      final result = await _connection!.execute(
        '''INSERT INTO POI (
         FID, MID, PX, PY, 
         PName, PEditMonth, PEditYear,
         PDescription, PIconName
       ) VALUES (
         :fid, :mid, :px, :py,
         :pName, :editMonth, :editYear,
         :pDescription, :pIconName
       )''',
        {
          'fid': fid,
          'mid': mid,
          'px': px,
          'py': py,
          'pName': pName,
          'editMonth': editMonth,
          'editYear': editYear > 100 ? editYear % 100 : editYear,
          'pDescription': pDescription,
          'pIconName': pIconName,
        },
      );

      final affectedRows = result.affectedRows.toInt();
      if (affectedRows > 0) {
        final lastIdResult =
            await _connection!.execute('SELECT LAST_INSERT_ID() as pid');

        // Safely handle the conversion
        final pidString = lastIdResult.rows.first.assoc()['pid'].toString();
        final pid = int.tryParse(pidString);

        if (pid == null) {
          print('Warning: Could not parse PID as integer: $pidString');
          return null;
        }
        return pid;
      } else {
        return null;
      }

      // Return the auto-generated PID
    } catch (e, stack) {
      print('Error adding POI: $e');
      print('Stack trace: $stack');
      return null;
    }
  }

//  Update POI Info
  static Future<bool> updatePOI({
    required int poiId,
    required int mapId,
    int? newFloorId,
    int? newX,
    int? newY,
    String? newName,
    int? newMonth,
    int? newYear,
    String? newDescription,
    String? newIconName,
  }) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      // 1. Prepare the update fields
      final updateFields = <String, dynamic>{};

      if (newFloorId != null) updateFields['FID'] = newFloorId;
      if (newX != null) updateFields['PX'] = newX;
      if (newY != null) updateFields['PY'] = newY;
      if (newName != null) updateFields['PName'] = newName;
      if (newDescription != null) updateFields['PDescription'] = newDescription;
      if (newIconName != null) updateFields['PIconName'] = newIconName;

      // Handle month/year updates separately
      if (newMonth != null) {
        if (newMonth < 1 || newMonth > 12) {
          throw Exception('Month must be between 1-12');
        }
        updateFields['PEditMonth'] = newMonth;
      }

      if (newYear != null) {
        updateFields['PEditYear'] = newYear > 100 ? newYear % 100 : newYear;
      }

      // 2. If no fields to update, return false
      if (updateFields.isEmpty) return false;

      // 3. Build the SQL query
      final fieldUpdates =
          updateFields.keys.map((field) => '$field = :$field').join(', ');
      final query =
          'UPDATE POI SET $fieldUpdates WHERE PID = :poiId AND MID = :mapId';

      // 4. Execute with all parameters
      final params = {'poiId': poiId, 'mapId': mapId, ...updateFields};
      final result = await _connection!.execute(query, params);

      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error updating POI: $e');
      return false;
    }
  }

//  Get POI Methods to Print it to User
  static Future<Map<String, dynamic>> getPOIInfo(int poiId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        '''SELECT 
         PID, MID, FID, PX, PY, 
         PName, PEditMonth, PEditYear,
         PDescription, PIconName
         FROM POI 
         WHERE PID = :poiId''',
        {'poiId': poiId},
      );

      if (result.rows.isEmpty) {
        return {'error': 'POI with ID $poiId not found', 'exists': false};
      }

      final poiData = result.rows.first.assoc();

      // Format the date from separate month/year fields
      final month = poiData['PEditMonth'].toString().padLeft(2, '0');
      final year = poiData['PEditYear'].toString().padLeft(2, '0');
      final formattedDate = '$month/$year';

      // Build both the formatted string and return the raw data
      return {
        'exists': true,
        'formattedInfo': '''
POI ID: ${poiData['PID']}
Map ID: ${poiData['MID']}
Floor ID: ${poiData['FID']}
Coordinates: (${poiData['PX']}, ${poiData['PY']})
Name: ${poiData['PName']}
Icon: ${poiData['PIconName'] ?? 'Default'}
Last Edited: $formattedDate
Description: ${poiData['PDescription'] ?? 'No description'}
''',
        'rawData': {
          'PID': poiData['PID'],
          'MID': poiData['MID'],
          'FID': poiData['FID'],
          'PX': poiData['PX'],
          'PY': poiData['PY'],
          'PName': poiData['PName'],
          'PEditMonth': poiData['PEditMonth'],
          'PEditYear': poiData['PEditYear'],
          'PDescription': poiData['PDescription'],
          'PIconName': poiData['PIconName'],
        }
      };
    } catch (e) {
      print('Error retrieving POI info: $e');
      return {
        'error': 'Error retrieving POI information: ${e.toString()}',
        'exists': false
      };
    }
  }

//  Get POI Data As Map Structure  (use inside methods)
  static Future<Map<String, dynamic>?> getPOIData(int poiId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        '''SELECT 
         PID, MID, FID, PX, PY, 
         PName, PEditMonth, PEditYear,
         PDescription, PIconName
         FROM POI 
         WHERE PID = :poiId''',
        {'poiId': poiId},
      );

      if (result.rows.isEmpty) return null;
      return result.rows.first.assoc();
    } catch (e) {
      print('Error retrieving POI data: $e');
      return null;
    }
  }

// Delete POI
  static Future<bool> deletePOI(int poiId, int mapId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'DELETE FROM POI WHERE PID = :poiId AND MID = :mapId',
        {'poiId': poiId, 'mapId': mapId},
      );
      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error deleting POI: $e');
      return false;
    }
  }

// check if user can edit POI
  static Future<bool> doesUserHavePOIAccess(int userId, int poiId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'SELECT COUNT(*) as count FROM User_POI WHERE UID = :userId AND PID = :poiId',
        {'userId': userId, 'poiId': poiId},
      );

      // Convert the count to an integer before comparison
      final countString = result.rows.first.assoc()['count']?.toString();
      final count = int.tryParse(countString ?? '0') ?? 0;
      return count > 0;
    } catch (e) {
      print('Error checking user-POI access: $e');
      return false;
    }
  }

// make user id to edit POI id
  static Future<bool> addUserPOIRelation(int userId, int poiId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'INSERT INTO User_POI (UID, PID) VALUES (:userId, :poiId)',
        {'userId': userId, 'poiId': poiId},
      );
      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error adding user-POI relation: $e');
      return false;
    }
  }

// remove user from editing list
  static Future<bool> removeUserPOIRelation(int userId, int poiId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        'DELETE FROM User_POI WHERE UID = :userId AND PID = :poiId',
        {'userId': userId, 'poiId': poiId},
      );
      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error removing user-POI relation: $e');
      return false;
    }
  }

// Helper method to get current date values
  static Future<Map<String, int>> _getCurrentPoiDate(int poiId) async {
    final result = await _connection!.execute(
      'SELECT PEditDateMMYY FROM POI WHERE PID = :poiId',
      {'poiId': poiId},
    );

    if (result.rows.isEmpty) throw Exception('POI not found');

    final date = result.rows.first.assoc()['PEditDateMMYY'] as int;
    return {
      'month': date % 100,
      'year': (date ~/ 100) + 2000, // Assuming 21st century
    };
  }

// Helper method to get date in format  YYYYMMDD
  static int _getCurrentDateInFormat() {
    final now = DateTime.now();
    final year = now.year % 100; //( 25 for 2025)
    final month = now.month; // Month
    final day = now.day; // Day

    // Format: YYMMDD \250405
    return (year * 10000) + (month * 100) + day;
  }

//  Section 6 : Viewing Related Methods
//  Get Maps info with its Floors
//  Get Floor Details  -  Get Metadata of POI

// get each map info with its floors id and names  and return a map data type
  static Future<List<Map<String, dynamic>>> getMapsWithFloors() async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      // Fetch all maps
      final mapsResult = await _connection!.execute(
        'SELECT * FROM Map ORDER BY MID DESC',
      );

      if (mapsResult.rows.isEmpty) return [];

      final List<Map<String, dynamic>> mapsWithFloors = [];

      // For each map, fetch its floors
      for (final row in mapsResult.rows) {
        final mapData = row.assoc();
        final mid = mapData['MID'];

        // Fetch floors for this map
        final floorsResult = await _connection!.execute(
          'SELECT FID, FName FROM Floor WHERE MID = :mid',
          {'mid': mid},
        );

        final List<Map<String, dynamic>> floors =
            floorsResult.rows.map((floorRow) => floorRow.assoc()).toList();

        mapsWithFloors.add({
          'map': mapData,
          'floors': floors,
        });
      }

      return mapsWithFloors;
    } catch (e) {
      print('Error fetching maps with floors: $e');
      return [];
    }
  }

// get Floor details
  static Future<Map<String, dynamic>?> getFloorDetailsWithMapInfo(
      int floorId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final floorResult = await _connection!.execute(
        '''SELECT 
         F.FID, F.FName, F.FImage, F.MID,
         M.MName
         FROM Floor F
         JOIN Map M ON F.MID = M.MID
         WHERE F.FID = :floorId''',
        {'floorId': floorId},
      );

      if (floorResult.rows.isEmpty) {
        return null;
      }

      final rowMap = floorResult.rows.first.assoc(); // Convert row to map
      return rowMap;
      // return {
      //   'floorId': rowMap['FID'],
      //   'floorName': rowMap['FName'],
      //   'floorImage': rowMap['FImage'],
      //   'mapId': rowMap['MID'],
      //   'mapName': rowMap['MName'],
      // };
    } catch (e) {
      print('Error retrieving floor details for $floorId: $e');
      return null;
    }
  }

// get POI based on Floor ID
  static Future<List<Map<String, dynamic>>> getPOIsByFloorId(
      int floorId) async {
    if (_connection == null) {
      throw Exception('Database connection not initialized');
    }

    try {
      final result = await _connection!.execute(
        '''SELECT PID, PName, PIconName, PX, PY FROM POI WHERE FID = :floorId''',
        {'floorId': floorId},
      );

      return result.rows.map((row) {
        final rowMap = row.assoc();

        // Safely extract and convert values
        final pid = int.tryParse(rowMap['PID'].toString()) ?? 0;
        final x = double.tryParse(rowMap['PX'].toString()) ?? 0.0;
        final y = double.tryParse(rowMap['PY'].toString()) ?? 0.0;

        return {
          'pid': pid,
          'name': rowMap['PName']?.toString() ?? 'Unnamed POI',
          'icon': rowMap['PIconName']?.toString(),
          'x': x,
          'y': y,
        };
      }).toList();
    } catch (e) {
      print('Error retrieving POIs: $e');
      return [];
    }
  }

  // Hashing Method
  static String generate250CharHash(String input) {
    // Create initial SHA-512 hash (which is 128 hex characters)
    var bytes = utf8.encode(input);
    var digest = sha512.convert(bytes);

    // Use the initial hash as seed for iterative hashing to reach 250 chars
    String hash = digest.toString();

    while (hash.length < 250) {
      bytes = utf8.encode(hash);
      digest = sha512.convert(bytes);
      hash += digest.toString();
    }

    // Trim to exactly 250 characters
    return hash.substring(0, 250);
  }

  static DatabaseConnection? _connectionTest;

  // Add this setter method
  // Add this to your DBConnection class
  static void setTestConnection(DatabaseConnection connection) {
    _connectionTest = connection;
  }
}

//  Section 7 : Testing

// Add this interface if not already present
abstract class DatabaseConnection {
  static DatabaseConnection? _connection;

  Future<dynamic> execute(String query, Map<String, dynamic> params);
}
