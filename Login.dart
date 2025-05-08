import 'package:flutter/material.dart';
import 'package:myfirst/AddUser.dart';
import 'package:myfirst/EditUser.dart';
import '../DBConnection.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    DBConnection.initialize();
  }

  Future<void> _login() async {
    final uid = int.tryParse(_uidController.text.trim());
    final pass = _passController.text.trim();

    if (uid == null || pass.isEmpty) {
      setState(() {
        _errorMessage = 'Wrong ID or Empty Password';
      });
      return;
    }

    try {
      final isLoggedIn = await Login.logIn(uid, pass);
      if (isLoggedIn) {
        // print('\n\n\ngggggggggggg\n\n\n');

        setState(() {
          _errorMessage = 'correct';
        });
        
      } else {
        setState(() {
          _errorMessage = 'wrong';
        });
      }

    } on OutOfMemoryError {
      print("Critical error: Device memory full!");
    }catch (e) {
      print('Error: $e');
      setState(() {
        _errorMessage = 'An error occurred. Please try again later.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Log In'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _uidController,
              decoration: InputDecoration(
                labelText: 'Enter UID',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passController,
              decoration: InputDecoration(
                labelText: 'Enter Password',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.visiblePassword,
            ),
            SizedBox(height: 20),
            Text(
                _errorMessage == 'correct' ? 'User Logged In'
                : _errorMessage == '' ? '' :'User not Exist',
                style: TextStyle(color: _errorMessage == 'correct' ? Colors.blue : Colors.red),
              ),
            // if (_errorMessage.isEmpty)
            //   Text(
            //     '',
            //     style: TextStyle(color: Colors.black),
            //   ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: Text('Login'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserAccount()),
                );
              },
              child: const Text('New Account'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EditUserInfo()),
                  );
                },
                child: const Text('Edit Info'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }
}

class Login {
  static Map<String, dynamic>? currentUser;

  static Future<bool> logIn(int ID, String password) async {
    try {
      final user = await DBConnection.logInByID(ID, password);

      if (user != null) {
        currentUser = user;
        return true;
      } else {
        currentUser = null;
        return false;
      }
    } catch (e) {
      print('Error during login: $e');
      currentUser = null;
      return false;
    }
  }

  static String? getCurrentUserName() {
    return currentUser?['UName'];
  }

  static int? getCurrentUserId() {
    final uid = currentUser?['UID'];
    return uid is String ? int.tryParse(uid) : uid as int?;
  }

  static int? getCurrentUserIsAdmin() {
    final uIsAdmin = currentUser?['UIsAdmin'];
    return uIsAdmin is String ? int.tryParse(uIsAdmin) : uIsAdmin as int?;
  }
}

