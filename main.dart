import 'package:flutter/material.dart';
import 'package:myfirst/AddMap.dart';
import 'package:myfirst/AddPOI.dart';
import 'package:myfirst/Admin.dart';
import 'package:myfirst/DBConnection.dart';
import 'package:myfirst/EditPOI.dart';
import 'package:myfirst/ViewPOI.dart';
import 'package:myfirst/AddFloor.dart';
import 'package:myfirst/ViewFloor.dart';
import 'package:myfirst/EditUser.dart';
import 'package:myfirst/ViewMap.dart';

import '../Login.dart';

void main() async {
  try {
    await DBConnection.initialize();
    runApp(MyApp());
  } catch (e) {
    print(e);
  } finally {
    print("DB not Initialized :(");
    runApp(MyApp());
  }
}

// Define the MyApp widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyWidget(),
    );
  }
}

// Define the MyWidget widget
class MyWidget extends StatefulWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

// Define the state for MyWidget
class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Map'),
        backgroundColor: const Color.fromARGB(255, 90, 181, 255),
      ),
      backgroundColor: Colors.blue,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(
                height: 40,
                width: double.infinity,
              ),
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue,
                backgroundImage: AssetImage('assets/images/SyncMap Icon.png'),
              ),
              const SizedBox(
                height: 10,
              ),
              Text(
                '${Login.getCurrentUserName() ?? 'Hi User .. Get Started !!'} ',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 4,
              ),
              Text(
                'Never Get Lost',
                style: TextStyle(
                  color: Colors.grey.shade200,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(
                height: 10,
                width: 300,
                child: Divider(),
              ),
              SizedBox(
                width: 350,
                child: Card(
                  color: const Color.fromARGB(255, 12, 105, 180),
                  child: ListTile(
                    leading: const Icon(
                      Icons.directions_run,
                      color: Colors.white,
                      size: 25,
                    ),
                    title: Text(
                      'Where to go ?',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.grey.shade200,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 350,
                child: Card(
                  margin: const EdgeInsets.all(5),
                  color: const Color.fromARGB(255, 12, 105, 180),
                  child: ListTile(
                    leading: const Icon(
                      Icons.explore,
                      color: Colors.white,
                      size: 25,
                    ),
                    title: Text(
                      'Lost in the maze of possibilities .. !',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.grey.shade200,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 15,
              ),
              SizedBox(height: 16,),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                  );
                },
                child: const Text('User Access 👤'),
              ),
              SizedBox(height: 16,),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddMap()),
                  );
                },
                child: const Text('Map Access ⛪'),
              ),
              SizedBox(height: 16,),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddFloorWidget()),
                  );
                },
                child: const Text('Floor Access 🗺️'),
              ),
              SizedBox(height: 16,),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => MapsWithFloorsView()),
                  );
                },
                child: const Text('List Maps 📃'),
              ),
              SizedBox(height: 16,),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => AdminManagementWidget()),
                  );
                },
                child: const Text('Manage Access 👁️‍🗨️'),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
