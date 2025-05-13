import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart'; //firebase realtime database connection
import 'package:shared_preferences/shared_preferences.dart'; // Added for Shared Preferences
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';

// Firebase connection details
const String firebaseHost =
    "riskband-7551a-default-rtdb.asia-southeast1.firebasedatabase.app";
const String firebaseAuth = "fJ0y6TGCa730ewDi3ols8we5DWWGZjHMeeodcOQF";

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Notification permission setup
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted permission for notifications');
  } else {
    print('User denied permission');
  }

  // Notification initialization
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload == 'emergency_alert') {
        // Extract data from the payload if needed
        // Navigate to the emergency alert screen or show the alert dialog
        // You may need to pass the heart rate, spo2, etc. from the payload
        _showEmergencyAlert(
          navigatorKey.currentContext!,
          int.parse(response.payload?.split(',')[0] ?? '0'), // heartRate
          int.parse(response.payload?.split(',')[1] ?? '0'), // spo2
          double.parse(response.payload?.split(',')[2] ?? '0.0'), // latitude
          double.parse(response.payload?.split(',')[3] ?? '0.0'), // longitude
        );
      }
    },
  );

  // Load shared preferences
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? userType = prefs.getString('userType');
  String? relativeName = prefs.getString('relativeName');
  String? patientName = prefs.getString('patientName');
  String? contact = prefs.getString('contact');

  // Start app with overlay support
  runApp(
    OverlaySupport.global(
      child: MyApp(
        userType: userType,
        relativeName: relativeName,
        patientName: patientName,
        contact: contact,
        navigatorKey: navigatorKey, // Pass this to MyApp
      ),
    ),
  );
}

void setupHealthDataListener(Function(Map<String, dynamic>) onDataReceived) {
  Query refHealth = FirebaseDatabase.instance.ref("health_data").limitToLast(1);

  // Optional: Keep the listener synced for better reliability
  refHealth.keepSynced(true);

  refHealth.onValue.listen((DatabaseEvent event) {
    final dataSnapshot = event.snapshot;

    if (dataSnapshot.exists && dataSnapshot.value != null) {
      Map<dynamic, dynamic> healthData =
          dataSnapshot.value as Map<dynamic, dynamic>;
      Map<String, dynamic> latestEntry = {};

      // Safely extract the only/latest item
      healthData.forEach((key, value) {
        latestEntry = Map<String, dynamic>.from(value);
      });

      onDataReceived({
        'heartRate': int.tryParse(latestEntry['heart_rate'].toString()) ?? 0,
        'spo2': int.tryParse(latestEntry['spo2'].toString()) ?? 0,
        'latitude': double.tryParse(latestEntry['latitude'].toString()) ?? 0.0,
        'longitude':
            double.tryParse(latestEntry['longitude'].toString()) ?? 0.0,
        // Future-proof:
        // 'battery': int.tryParse(latestEntry['battery'].toString()) ?? 0,
        // 'location': latestEntry['location']?.toString() ?? "Location not available",
      });
    } else {
      print("No data found at the specified reference for health data.");
      onDataReceived({
        'heartRate': 0,
        'spo2': 0,
        'latitude': 0.0,
        'longitude': 0.0,
      });
    }
  });
}

void initializeNotifications() {
  final AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

/*
void setupHealthDataListener(Function(Map<String, dynamic>) onDataReceived) {
  Query refHealth = FirebaseDatabase.instance.ref("health_data").limitToLast(1);

  // Optional: Keep the listener synced for better reliability
  refHealth.keepSynced(true);

  refHealth.onValue.listen((DatabaseEvent event) {
    final dataSnapshot = event.snapshot;

    if (dataSnapshot.exists && dataSnapshot.value != null) {
      Map<dynamic, dynamic> healthData =
          dataSnapshot.value as Map<dynamic, dynamic>;
      Map<String, dynamic> latestEntry = {};

      // Safely extract the only/latest item
      healthData.forEach((key, value) {
        latestEntry = Map<String, dynamic>.from(value);
      });

      onDataReceived({
        'heartRate': int.tryParse(latestEntry['heart_rate'].toString()) ?? 0,
        'spo2': int.tryParse(latestEntry['spo2'].toString()) ?? 0,
        'latitude': double.tryParse(latestEntry['latitude'].toString()) ?? 0.0,
        'longitude':
            double.tryParse(latestEntry['longitude'].toString()) ?? 0.0,
        // Future-proof:
        // 'battery': int.tryParse(latestEntry['battery'].toString()) ?? 0,
        // 'location': latestEntry['location']?.toString() ?? "Location not available",
      });
    } else {
      print("No data found at the specified reference for health data.");
      onDataReceived({
        'heartRate': 0,
        'spo2': 0,
        'latitude': 0.0,
        'longitude': 0.0,
      });
    }
  });
}*/

class MyApp extends StatelessWidget {
  final String? userType;
  final String? relativeName;
  final String? patientName;
  final String? contact;
  final GlobalKey<NavigatorState> navigatorKey;

  const MyApp({
    super.key,
    this.userType,
    this.relativeName,
    this.patientName,
    this.contact,
    required this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Health App Interface',
      theme: ThemeData(primarySwatch: Colors.blue),
      home:
          (userType == 'relative' &&
                  relativeName != null &&
                  patientName != null &&
                  contact != null)
              ? RelativeMonitoringScreen(
                relativeName: relativeName!,
                patientName: patientName!,
                contact: contact!,
              )
              : (userType == 'patient' &&
                  patientName != null &&
                  relativeName != null &&
                  contact != null)
              ? PatientMonitoringScreen(
                patientName: patientName!,
                relativeName: relativeName!,
                relativeContact: contact!,
              )
              : HomePage(),
      navigatorKey: navigatorKey,
      routes: {
        '/relative': (context) => RelativeScreen(),
        '/patient': (context) => PatientScreen(),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFCC33), Color(0xFF6699CC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.jpg', height: 100, width: 100),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RelativeScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: BorderSide(color: Colors.black),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text("RELATIVE"),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PatientScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: BorderSide(color: Colors.black),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text("PATIENT"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Relative login screen
class RelativeScreen extends StatefulWidget {
  @override
  _RelativeScreenState createState() => _RelativeScreenState();
}

class _RelativeScreenState extends State<RelativeScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController patientNameController = TextEditingController();
  final TextEditingController contactController = TextEditingController();

  bool isSignedUp = false;
  String? nameError;
  String? patientNameError;
  String? contactError;

  void validateAndSave() {
    setState(() {
      nameError =
          nameController.text.isEmpty ? "Please fill up the text field" : null;
      patientNameError =
          patientNameController.text.isEmpty
              ? "Please fill up the text field"
              : null;
      contactError =
          contactController.text.isEmpty
              ? "Please fill up the text field"
              : null;
    });

    if (nameError != null || patientNameError != null || contactError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please fill up all the text fields"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(nameController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please avoid special characters and numbers."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(patientNameController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please avoid special characters and numbers."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    if (contactController.text.length != 11 ||
        !RegExp(r'^[0-9]+$').hasMatch(contactController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Contact number must be 11 digits and contain only numbers",
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    String capitalize(String s) => s
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
    String relativeName = capitalize(nameController.text.trim());
    String patientName = capitalize(patientNameController.text.trim());

    setState(() {
      isSignedUp = true;
    });

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('userType', 'relative');
      prefs.setString('relativeName', relativeName);
      prefs.setString('patientName', patientName);
      prefs.setString('contact', contactController.text);
    });

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder:
            (context) => RelativeMonitoringScreen(
              relativeName: relativeName,
              patientName: patientName,
              contact: contactController.text,
            ),
      ),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Relative Sign-Up")),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFCC33), Color(0xFF6699CC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "RELATIVE",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Name: ",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    errorText: nameError,
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: patientNameController,
                  decoration: InputDecoration(
                    labelText: "Name of Patient: ",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    errorText: patientNameError,
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: contactController,
                  decoration: InputDecoration(
                    labelText: "Contact: ",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    errorText: contactError,
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 20),
                Container(
                  color: const Color.fromARGB(79, 35, 33, 33),
                  padding: EdgeInsets.all(6.0),
                  child: Text(
                    "Reminder: \n     Please double-check your information before saving.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: validateAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text("Save"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Relative monitoring screen
class RelativeMonitoringScreen extends StatefulWidget {
  final String relativeName;
  final String patientName;
  final String contact;

  RelativeMonitoringScreen({
    required this.relativeName,
    required this.patientName,
    required this.contact,
  });

  @override
  _RelativeMonitoringScreenState createState() =>
      _RelativeMonitoringScreenState();
}

class _RelativeMonitoringScreenState extends State<RelativeMonitoringScreen> {
  int heartRate = 0; // Initialize with default value
  int spo2 = 0; // Initialize with default value
  double latitude = 0.0; // Initialize with default value
  double longitude = 0.0; // Initialize with default value // Add longitude
  //late int battery; TO BE ADDED
  //late String location;

  @override
  void initState() {
    super.initState();
    setupHealthDataListener((data) {
      setState(() {
        heartRate = data['heartRate'];
        spo2 = data['spo2'];
        latitude = data['latitude'];
        longitude = data['longitude'];
      });

      handleSensorData(
        context,
        data['heartRate'],
        data['spo2'],
        data['latitude'],
        data['longitude'],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFCC33), Color(0xFF6699CC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(10),
                //child: Text("Battery: $battery%", style: TextStyle(fontSize: 20)), TO BE ADDED
              ),
            ),
            Center(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          heartRate > 0
                              ? "$heartRate ❤️"
                              : "No Heart Rate Data",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 50,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          spo2 > 0 ? "$spo2% SpO2" : "No SpO2 Data",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FloatingActionButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HotlineScreen(),
                            ),
                          );
                        },
                        backgroundColor: Colors.black,
                        child: Icon(Icons.phone, color: Colors.white),
                      ),
                      SizedBox(width: 20),
                      FloatingActionButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FirstAidScreen(),
                            ),
                          );
                        },
                        backgroundColor: Colors.black,
                        child: Icon(
                          Icons.medical_services,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  // original code

                  //POPUP ALERT
                  /*SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      _showEmergencyAlert(
                        context,
                        heartRate,
                        spo2,
                        latitude,
                        longitude,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,

                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text("Emergency Alert"),
                  ),*/
                  SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person, color: Colors.black, size: 30),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "RELATIVE",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text("Name: ${widget.relativeName}"),
                          Text("Name of Patient: ${widget.patientName}"),
                          Text("Contact: ${widget.contact}"),
                        ],
                      ),
                    ],
                  ),
                  /*Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton(
                      onPressed: () async {
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        await prefs.clear();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => HomePage()),
                          (Route<dynamic> route) => false,
                        );
                      },
                      child: Text("Logout"),
                    ),
                  ),*/
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// First Aid Screen on relative
class FirstAidScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("First Aid Guide")),
      body: SingleChildScrollView(
        child: Center(
          child: Image.asset('assets/firstaid.jpg', fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// Patient sign-up screen
class PatientScreen extends StatefulWidget {
  @override
  _PatientScreenState createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController relativeNameController = TextEditingController();
  final TextEditingController relativeContactController =
      TextEditingController();

  bool isSignedUp = false;
  String? nameError;
  String? relativeNameError;
  String? relativeContactError;

  void validateAndSave() {
    setState(() {
      nameError =
          nameController.text.isEmpty ? "Please fill up the text field" : null;
      relativeNameError =
          relativeNameController.text.isEmpty
              ? "Please fill up the text field"
              : null;
      relativeContactError =
          relativeContactController.text.isEmpty
              ? "Please fill up the text field"
              : null;
    });

    if (nameError != null ||
        relativeNameError != null ||
        relativeContactError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please fill up all the text fields"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(nameController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please avoid special characters and numbers."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    if (!RegExp(
      r'^[a-zA-Z\s]+$',
    ).hasMatch(relativeNameController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please avoid special characters and numbers."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    if (relativeContactController.text.length != 11 ||
        !RegExp(r'^[0-9]+$').hasMatch(relativeContactController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Contact number must be 11 digits and contain only numbers",
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    String capitalize(String s) => s
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
    String patientName = capitalize(nameController.text.trim());
    String relativeName = capitalize(relativeNameController.text.trim());

    setState(() {
      isSignedUp = true;
    });

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('userType', 'patient');
      prefs.setString('relativeName', relativeName);
      prefs.setString('patientName', patientName);
      prefs.setString('contact', relativeContactController.text);
    });

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder:
            (context) => PatientMonitoringScreen(
              patientName: patientName,
              relativeName: relativeName,
              relativeContact: relativeContactController.text,
            ),
      ),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Patient Sign-Up")),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFCC33), Color(0xFF6699CC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "PATIENT",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Name: ",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    errorText: nameError,
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: relativeNameController,
                  decoration: InputDecoration(
                    labelText: "Name of Relative: ",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    errorText: relativeNameError,
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: relativeContactController,
                  decoration: InputDecoration(
                    labelText: "Contact of Relative: ",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    errorText: relativeContactError,
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 20),
                Container(
                  color: const Color.fromARGB(79, 35, 33, 33),
                  padding: EdgeInsets.all(6.0),
                  child: Text(
                    "Reminder: \n     Please double-check your information before saving.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: validateAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text("Save"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Patient monitoring screen
class PatientMonitoringScreen extends StatefulWidget {
  final String patientName;
  final String relativeName;
  final String relativeContact;

  PatientMonitoringScreen({
    required this.patientName,
    required this.relativeName,
    required this.relativeContact,
  });

  @override
  _PatientMonitoringScreenState createState() =>
      _PatientMonitoringScreenState();
}

class _PatientMonitoringScreenState extends State<PatientMonitoringScreen> {
  int heartRate = 0; // Initialize with default value
  int spo2 = 0; // Initialize with default value
  double latitude = 0.0; // Initialize with default value
  double longitude = 0.0; // Initialize with default value
  //late int battery; // TO BE ADDED
  //late String location;

  @override
  void initState() {
    super.initState();
    setupHealthDataListener((data) {
      setState(() {
        heartRate = data['heartRate'];
        spo2 = data['spo2'];
        latitude = data['latitude'];
        longitude = data['longitude'];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFCC33), Color(0xFF6699CC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(10),
                //child: Text("Battery: $battery%", style: TextStyle(fontSize: 20)), // TO BE ADDED
              ),
            ),
            Center(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          heartRate > 0
                              ? "$heartRate ❤️"
                              : "No Heart Rate Data",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 50,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          spo2 > 0 ? "$spo2% SpO2" : "No SpO2 Data",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  FloatingActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HotlineScreen(),
                        ),
                      );
                    },
                    backgroundColor: Colors.black,
                    child: Icon(Icons.phone, color: Colors.white),
                  ),
                  SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person, color: Colors.black, size: 30),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "PATIENT",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text("Name: ${widget.patientName}"),
                          Text("Name of Relative: ${widget.relativeName}"),
                          Text(
                            "Contact of Relative: ${widget.relativeContact}",
                          ),
                        ],
                      ),
                    ],
                  ),
                  /*Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton(
                      onPressed: () async {
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        await prefs.clear();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => HomePage()),
                          (Route<dynamic> route) => false,
                        );
                      },
                      child: Text("Logout"),
                    ),
                  ),*/
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Emergency hotline screen
class HotlineScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Emergency Hotlines")),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Image.asset('assets/hotline.jpg', fit: BoxFit.cover),
      ),
    );
  }
}

// Function to play audio from URL
void playAudioFromUrl(AudioPlayer player) async {
  await player.play(AssetSource('alert_sound.mp3'));
}

Future<String> getAddressFromLatLng(double latitude, double longitude) async {
  try {
    List<Placemark> placemarks = await placemarkFromCoordinates(
      latitude,
      longitude,
    );
    Placemark place = placemarks[0]; // Get the first placemark
    return "${place.street},${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}"; // Format the address
  } catch (e) {
    print(e);
    return "Location not available"; // Return a default message in case of error
  }
}

bool _alertActive = false;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

AudioPlayer _player =
    AudioPlayer(); // Declare and initialize a single instance of AudioPlayer

Future<void> _showEmergencyAlert(
  BuildContext context,
  int heartRate,
  int spo2,
  double latitude,
  double longitude,
) async {
  String address = await getAddressFromLatLng(latitude, longitude);

  // Sound + vibration while in foreground
  if (context.mounted) {
    _player.setReleaseMode(ReleaseMode.loop);
    playAudioFromUrl(_player);
    Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
  }

  // Full-screen modal alert
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            SizedBox(width: 8),
            Text(
              "🚨 Emergency Alert",
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("❤️ Heart Rate: $heartRate BPM"),
            Text("🩸 SpO₂ Level: $spo2%"),
            SizedBox(height: 10),
            Text("📍 Location: $address"),
            Text("Latitude: $latitude"),
            Text("Longitude: $longitude"),
            SizedBox(height: 10),
            Text(
              "⚠️ Possible heart issue detected.",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Vibration.cancel();
              _player.stop();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Emergency alert acknowledged."),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: Text("Confirm"),
          ),
        ],
      );
    },
  );

  // Full-screen push notification (background/locked state)
  await showEmergencyNotification(heartRate, spo2, address);
}

Future<void> showEmergencyNotification(
  int heartRate,
  int spo2,
  String address,
) async {
  final androidDetails = AndroidNotificationDetails(
    'emergency_channel_id',
    'Emergency Alerts',
    channelDescription: 'Channel for full-screen emergency alerts',
    importance: Importance.max,
    priority: Priority.high,
    fullScreenIntent: true,
    styleInformation: BigTextStyleInformation(
      '❤️ $heartRate BPM • 🩸 $spo2%\n📍 $address',
      contentTitle: '🚨 Emergency Alert!',
      summaryText: 'Emergency data received',
    ),
    ticker: 'emergency',
    icon: '@mipmap/ic_launcher',
    color: Colors.red,
  );

  final platformChannelSpecifics = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    0,
    '🚨 Emergency Alert!',
    '❤️ $heartRate BPM • 🩸 $spo2% • 📍 Tap for location',
    platformChannelSpecifics,
    payload: 'emergency_alert', // Used for navigation when tapped
  );
}

void handleSensorData(
  BuildContext context,
  int heartRate,
  int spo2,
  double latitude,
  double longitude,
) {
  if (heartRate >= 100 || heartRate <= 50 && !_alertActive) {
    _alertActive = true;
    _showEmergencyAlert(context, heartRate, spo2, latitude, longitude);

    Future.delayed(Duration(seconds: 10), () {
      _alertActive = false;
    });
  }
}
