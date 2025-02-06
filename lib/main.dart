import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rxdart/rxdart.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:file_picker/file_picker.dart';

// AUTENTICAZIONE
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// PER SELEZIONARE FILE IMMAGINI/GPX
import 'package:image_picker/image_picker.dart';

// GOOGLE PLACES (importato per eventuali utilizzi)
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart' as g_ws;

// Import per il geocoding (per ricavare coordinate da un indirizzo)
import 'package:geocoding/geocoding.dart';

// Import della libreria math
import 'dart:math' as math;

//
// Impostiamo l'unica chiave API per tutte le piattaforme (Android, iOS e Web)
//
final String kGoogleApiKey = "AIzaSyCfbJdJg6LqwFdRQlbrnO3UYhV6OGC1yJc";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("[DEBUG] Inizio inizializzazione Firebase...");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print("[DEBUG] Firebase inizializzato correttamente.");

  await initializeDateFormatting('it_IT', null);
  print("[DEBUG] Formato date inizializzato.");

  runApp(const MyApp());
  print("[DEBUG] runApp eseguito.");
}

/// MyApp utilizza AuthWrapper per mostrare la LoginPage se l'utente non è autenticato
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print("[DEBUG] MyApp.build() invocato.");

    return MaterialApp(
      title: 'OUTS',
      debugShowCheckedModeBanner: false,
      // Forziamo il tema chiaro per evitare problemi di tema scuro
      theme: ThemeData(
        primarySwatch: Colors.amber,
        brightness: Brightness.light,
      ),
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('it', 'IT'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthWrapper(),
    );
  }
}

/// Wrapper che controlla se l'utente è loggato o meno.
/// Se loggato -> HomePage; se non loggato -> LoginPage
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    print("[DEBUG] AuthWrapper.build() invocato.");

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print(
            "[DEBUG] authStateChanges -> snapshot: ${snapshot.connectionState} / hasData=${snapshot.hasData}");
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          print("[DEBUG] Utente loggato, mostro HomePage.");
          return const HomePage();
        }
        print("[DEBUG] Nessun utente, mostro LoginPage.");
        return const LoginPage();
      },
    );
  }
}

// ––––––– LOGIN PAGE –––––––
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String _errorMessage = '';

  Future<void> _loginWithEmailAndPassword() async {
    setState(() {
      _loading = true;
      _errorMessage = '';
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Errore di autenticazione.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _loading = true;
      _errorMessage = '';
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() {
          _loading = false;
        });
        return;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Errore di autenticazione con Google.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _goToRegisterPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("[DEBUG] LoginPage.build() invocato.");

    return Scaffold(
      backgroundColor: const Color(0xFFEBB744),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 120,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Accedi per scoprire tutti gli eventi!',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage.isNotEmpty)
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: CircularProgressIndicator(),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _loginWithEmailAndPassword,
                      child: const Text('Accedi'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(FontAwesomeIcons.google),
                      label: const Text('Accedi con Google'),
                      onPressed: _loading ? null : _loginWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _goToRegisterPage,
                    child: const Text(
                      'Non hai un account? Registrati',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ––––––– PAGINA DI REGISTRAZIONE (AGGIORNATA) –––––––
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  final _nomeController = TextEditingController();
  final _cognomeController = TextEditingController();
  final _telefonoController = TextEditingController();

  List<String> _selectedSports = [];
  bool _loading = false;
  String _errorMessage = '';

  // Lista di sport disponibili per la multi-selezione
  final List<String> sportsOptions = [
    "E-MTB - MTB",
    "GRAVEL",
    "BICI DA STRADA",
    "TRAIL RUNNING",
    "ESCURSIONISMO",
  ];

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _errorMessage = '';
    });

    // Controllo password
    if (_passwordController.text != _passwordConfirmController.text) {
      setState(() {
        _errorMessage = 'Le password non combaciano.';
        _loading = false;
      });
      return;
    }

    try {
      // Creazione utente su Firebase Auth
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Salvataggio dati utente su Firestore
      await FirebaseFirestore.instance
          .collection("users")
          .doc(userCredential.user!.uid)
          .set({
        "email": _emailController.text.trim(),
        "nome": _nomeController.text.trim(),
        "cognome": _cognomeController.text.trim(),
        "telefono": _telefonoController.text.trim(),
        "sport": _selectedSports, // array con gli sport selezionati
      });

      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Errore di registrazione.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print("[DEBUG] RegisterPage.build() invocato.");

    return Scaffold(
      backgroundColor: const Color(0xFFEBB744),
      appBar: AppBar(
        title: const Text('Registrazione'),
        backgroundColor: const Color(0xFFD8A739),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              TextField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cognomeController,
                decoration: const InputDecoration(
                  labelText: 'Cognome',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _telefonoController,
                decoration: const InputDecoration(
                  labelText: 'Numero di Telefono',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              const Text('Seleziona gli sport praticati:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: sportsOptions.map((sport) {
                  final isSelected = _selectedSports.contains(sport);
                  return FilterChip(
                    label: Text(sport),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedSports.add(sport);
                        } else {
                          _selectedSports.remove(sport);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordConfirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Conferma Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              if (_loading) const CircularProgressIndicator(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: const Text('Registrati'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ––––––– FUNZIONE PER COSTRUIRE LA BOTTOM NAVIGATION BAR –––––––
BottomNavigationBar buildBottomNavBar(BuildContext context, int currentIndex) {
  return BottomNavigationBar(
    currentIndex: currentIndex,
    onTap: (int newIndex) {
      // Cliccando sempre viene effettuata la navigazione verso la pagina principale
      switch (newIndex) {
        case 0:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
          break;
        case 1:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SportPage()),
          );
          break;
        case 2:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const EventsPage()),
          );
          break;
        case 3:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          );
          break;
      }
    },
    backgroundColor: const Color(0xFFD8A739),
    selectedItemColor: Colors.black,
    unselectedItemColor: Colors.black54,
    items: const [
      BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Icon(FontAwesomeIcons.personRunning),
        label: 'Sport',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.event),
        label: 'Eventi',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.menu),
        label: 'Profilo',
      ),
    ],
  );
}

// ––––––– HOME PAGE (index=0) –––––––
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  final String whatsAppLink =
      "https://chat.whatsapp.com/EWnUsO5hhOk2SqE3EQtGvm";
  final String websiteLink = "https://www.outs.fun";

  void _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    print("[DEBUG] HomePage.build() invocato.");

    return Scaffold(
      bottomNavigationBar: buildBottomNavBar(context, 0),
      backgroundColor: const Color(0xFFEBB744),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Home'),
        backgroundColor: const Color(0xFFD8A739),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 240,
            ),
            const SizedBox(height: 10),
            const Text(
              'La tua community con cui organizzare e partecipare ad eventi outdoor',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _launchUrl(whatsAppLink),
              child: const Column(
                children: [
                  Icon(
                    FontAwesomeIcons.whatsapp,
                    size: 40,
                    color: Colors.green,
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Unisciti alla nostra Community su WhatsApp!",
                    style: TextStyle(fontSize: 14, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _launchUrl(websiteLink),
              child: const Text(
                "Visita il nostro sito web",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Benvenuto in OUTS!',
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ––––––– SPORT PAGE (index=1) –––––––
class SportPage extends StatelessWidget {
  const SportPage({super.key});

  @override
  Widget build(BuildContext context) {
    const double iconSizeSport = 216.0;

    return Scaffold(
      bottomNavigationBar: buildBottomNavBar(context, 1),
      backgroundColor: const Color(0xFFEBB744),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Sport'),
        backgroundColor: const Color(0xFFD8A739),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMenuItem(
                context,
                imagePath: 'assets/CICLISMO.png',
                label: 'Ciclismo',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CyclingPage()),
                ),
                size: iconSizeSport,
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                context,
                imagePath: 'assets/Podismo.png',
                label: 'Podismo',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PodismoPage()),
                ),
                size: iconSizeSport,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String imagePath,
    required String label,
    required VoidCallback onTap,
    required double size,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ––––––– PAGINE DISCIPLINE: CyclingPage e PodismoPage –––––––
class CyclingPage extends StatelessWidget {
  const CyclingPage({super.key});

  @override
  Widget build(BuildContext context) {
    const double iconSize = 120.0;
    const double spacing = 8.0;

    return Scaffold(
      bottomNavigationBar: buildBottomNavBar(context, 1),
      backgroundColor: const Color(0xFFEBB744),
      appBar: AppBar(
        title: const Text('Ciclismo'),
        backgroundColor: const Color(0xFFD8A739),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMenuItem(
                      context,
                      imagePath: 'assets/E-MTB - MTB.png',
                      label: 'E-MTB - MTB',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FirebaseSubPageWithMap(
                            collectionName: 'e-mtb-mtb',
                            title: 'E-MTB - MTB',
                            parentIndex: 1,
                          ),
                        ),
                      ),
                      size: iconSize,
                    ),
                    const SizedBox(height: spacing),
                    _buildMenuItem(
                      context,
                      imagePath: 'assets/GRAVEL.png',
                      label: 'GRAVEL',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FirebaseSubPageWithMap(
                            collectionName: 'GRAVEL',
                            title: 'GRAVEL',
                            parentIndex: 1,
                          ),
                        ),
                      ),
                      size: iconSize,
                    ),
                    const SizedBox(height: spacing),
                    _buildMenuItem(
                      context,
                      imagePath: 'assets/BICI DA CORSA.png',
                      label: 'BICI DA STRADA',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FirebaseSubPageWithMap(
                            collectionName: 'BICI DA STRADA',
                            title: 'BICI DA STRADA',
                            parentIndex: 1,
                          ),
                        ),
                      ),
                      size: iconSize,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String imagePath,
    required String label,
    required VoidCallback onTap,
    required double size,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class PodismoPage extends StatelessWidget {
  const PodismoPage({super.key});

  @override
  Widget build(BuildContext context) {
    const double iconSize = 120.0;
    const double spacing = 8.0;

    return Scaffold(
      bottomNavigationBar: buildBottomNavBar(context, 1),
      backgroundColor: const Color(0xFFEBB744),
      appBar: AppBar(
        title: const Text('Podismo'),
        backgroundColor: const Color(0xFFD8A739),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMenuItem(
                      context,
                      imagePath: 'assets/Trail Running.png',
                      label: 'TRAIL RUNNING',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FirebaseSubPageWithMap(
                            collectionName: 'TRAIL RUNNING',
                            title: 'TRAIL RUNNING',
                            parentIndex: 1,
                          ),
                        ),
                      ),
                      size: iconSize,
                    ),
                    const SizedBox(height: spacing),
                    _buildMenuItem(
                      context,
                      imagePath: 'assets/Escursionismo.png',
                      label: 'ESCURSIONISMO',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FirebaseSubPageWithMap(
                            collectionName: 'ESCURSIONISMO',
                            title: 'ESCURSIONISMO',
                            parentIndex: 1,
                          ),
                        ),
                      ),
                      size: iconSize,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String imagePath,
    required String label,
    required VoidCallback onTap,
    required double size,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ––––––– FUNZIONE DI UTILITÀ PER CALCOLARE LA DISTANZA IN KM (Haversine) –––––––
double _computeDistanceInKm(
    double lat1, double lon1, double lat2, double lon2) {
  const R = 6371; // Raggio terrestre in km
  double dLat = _deg2rad(lat2 - lat1);
  double dLon = _deg2rad(lon2 - lon1);
  double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

double _deg2rad(double deg) => deg * (math.pi / 180.0);

// ––––––– PAGINA CON MAPPA + FILTRO POSIZIONE (DISCIPLINE SPECIFICHE) –––––––
class FirebaseSubPageWithMap extends StatefulWidget {
  final String collectionName;
  final String title;
  final int parentIndex;

  const FirebaseSubPageWithMap({
    super.key,
    required this.collectionName,
    required this.title,
    required this.parentIndex,
  });

  @override
  State<FirebaseSubPageWithMap> createState() => _FirebaseSubPageWithMapState();
}

class _FirebaseSubPageWithMapState extends State<FirebaseSubPageWithMap> {
  // Variabili per il filtro posizione
  String? _enteredAddress;
  double? _filterLat;
  double? _filterLng;
  double _searchRadius = 10.0;
  bool _positionFilterActive = false;

  late Stream<List<DocumentSnapshot>> _eventsStream;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  // Aggiorniamo lo stream di base: i filtri di distanza li applichiamo lato client
  void _updateStream() {
    _eventsStream = FirebaseFirestore.instance
        .collection(widget.collectionName)
        .snapshots()
        .map((qs) => qs.docs);
  }

  // Apertura del dialog per filtrare per posizione
  void _openPositionFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController addressCtrl = TextEditingController(
          text: _enteredAddress ?? '',
        );

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> _searchAndSetCoordinates() async {
              final query = addressCtrl.text.trim();
              if (query.isNotEmpty) {
                try {
                  final locations = await locationFromAddress(query);
                  if (locations.isNotEmpty) {
                    final loc = locations.first;
                    setStateDialog(() {
                      _filterLat = loc.latitude;
                      _filterLng = loc.longitude;
                    });
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Indirizzo non trovato: $e')),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('Filtra per posizione'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: addressCtrl,
                      decoration: InputDecoration(
                        labelText: 'Inserisci punto di partenza',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _searchAndSetCoordinates,
                        ),
                      ),
                      onSubmitted: (_) => _searchAndSetCoordinates(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Raggio (km):'),
                        Expanded(
                          child: Slider(
                            value: _searchRadius,
                            min: 10,
                            max: 200,
                            divisions: 190,
                            label: '${_searchRadius.toStringAsFixed(0)} km',
                            onChanged: (value) {
                              setStateDialog(() {
                                _searchRadius = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _enteredAddress = null;
                      _filterLat = null;
                      _filterLng = null;
                      _searchRadius = 10.0;
                      _positionFilterActive = false;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Rimuovi filtro'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _enteredAddress = addressCtrl.text.trim();
                      if (_filterLat != null && _filterLng != null) {
                        _positionFilterActive = true;
                      } else {
                        _positionFilterActive = false;
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Applica'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: buildBottomNavBar(context, widget.parentIndex),
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFFD8A739),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _openPositionFilterDialog,
            icon: const Icon(Icons.location_on, color: Colors.black),
            label: const Text(
              "Posizione",
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFD8A739),
        onPressed: () {
          showCreateEventGlobalDialog(context, initialDiscipline: widget.title);
        },
        label: const Text('Crea Evento'),
      ),
      body: StreamBuilder<List<DocumentSnapshot>>(
        stream: _eventsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Applichiamo il filtro di distanza lato client se attivo
          List<DocumentSnapshot> events = snapshot.data!;
          if (_positionFilterActive &&
              _filterLat != null &&
              _filterLng != null) {
            events = events.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final lat = data['Location']?['Latitudine'] as double?;
              final lng = data['Location']?['Longitudine'] as double?;
              if (lat == null || lng == null) return false;
              final distance = _computeDistanceInKm(
                _filterLat!,
                _filterLng!,
                lat,
                lng,
              );
              return distance <= _searchRadius;
            }).toList();
          }

          final markers = <Marker>{};
          LatLng initialPos = const LatLng(45.0, 7.0);

          if (events.isNotEmpty) {
            for (var doc in events) {
              final data = doc.data() as Map<String, dynamic>;
              final lat = data['Location']?['Latitudine'] as double?;
              final lng = data['Location']?['Longitudine'] as double?;
              final title = data['Title'] ?? 'Evento';
              String dateStr = '';
              if (data['Date'] is Timestamp) {
                final ts = data['Date'] as Timestamp;
                dateStr = DateFormat('dd/MM/yyyy').format(ts.toDate());
              }
              if (lat != null && lng != null) {
                markers.add(
                  Marker(
                    markerId: MarkerId(doc.id),
                    position: LatLng(lat, lng),
                    infoWindow: InfoWindow(
                      title: title,
                      snippet: dateStr,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EventDetailsPage(
                              eventData: data,
                              eventDoc: doc,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
                initialPos = LatLng(lat, lng);
              }
            }
          }

          return Column(
            children: [
              SizedBox(
                height: 200,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialPos,
                    zoom: 12,
                  ),
                  markers: markers,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final data = event.data() as Map<String, dynamic>?;
                    if (data == null) return const SizedBox();
                    final title = data['Title'] ?? 'Senza titolo';
                    final discipline = data['Discipline'] ?? widget.title;
                    final desc = data['Description'] ?? '';
                    String dateStr = 'Data mancante';
                    if (data['Date'] is Timestamp) {
                      final ts = data['Date'] as Timestamp;
                      dateStr = DateFormat('dd/MM/yyyy').format(ts.toDate());
                    }
                    final shortDesc =
                        desc.length > 50 ? '${desc.substring(0, 50)}...' : desc;

                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        title: Text(title),
                        subtitle: Text('$discipline | $dateStr\n$shortDesc'),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () {
                          print(
                              "[DEBUG] Evento cliccato in ${widget.title}: $title");
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventDetailsPage(
                                eventData: data,
                                eventDoc: event,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ––––––– EVENTI (index=2) –––––––
class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  EventsPageState createState() => EventsPageState();
}

class EventsPageState extends State<EventsPage> {
  final List<String> _allDisciplines = [
    'E-MTB - MTB',
    'GRAVEL',
    'BICI DA STRADA',
    'TRAIL RUNNING',
    'ESCURSIONISMO',
  ];
  final Set<String> _selectedDisciplines = {};

  // Variabili per il filtro posizione
  String? _enteredAddress;
  double? _filterLat;
  double? _filterLng;
  double _searchRadius = 10.0;
  bool _positionFilterActive = false;

  // Label iniziale del bottone posizione
  String get locationButtonLabel =>
      _positionFilterActive ? "Posizione ($_searchRadius km)" : "Posizione";

  late Stream<List<DocumentSnapshot>> _eventsStream;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  void _updateStream() {
    if (_selectedDisciplines.isEmpty) {
      // Se non seleziono nulla, mostro TUTTE le discipline
      _eventsStream = _getAllEventsStream();
    } else {
      // Altrimenti unisco gli stream solo delle discipline selezionate
      final streams = _selectedDisciplines.map((disc) {
        return FirebaseFirestore.instance
            .collection(disc)
            .snapshots()
            .map((qs) => qs.docs);
      }).toList();

      if (streams.isEmpty) {
        _eventsStream = Stream.value([]);
      } else {
        _eventsStream =
            CombineLatestStream.list<List<DocumentSnapshot>>(streams)
                .map((listOfLists) {
          final allDocs = <DocumentSnapshot>[];
          for (final docs in listOfLists) {
            allDocs.addAll(docs);
          }
          return allDocs;
        });
      }
    }
  }

  Stream<List<DocumentSnapshot>> _getAllEventsStream() {
    final names = _allDisciplines;
    final streams = names.map((name) {
      return FirebaseFirestore.instance
          .collection(name)
          .snapshots()
          .map((qs) => qs.docs);
    }).toList();

    return CombineLatestStream.list<List<DocumentSnapshot>>(streams)
        .map((listOfLists) {
      final allDocs = <DocumentSnapshot>[];
      for (final docs in listOfLists) {
        allDocs.addAll(docs);
      }
      return allDocs;
    });
  }

  // Dialog per il filtro "Sport"
  void _openMultiDisciplineFilter() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final tempSelected = Set<String>.from(_selectedDisciplines);
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              title: const Text('Seleziona Sport'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _allDisciplines.map((disc) {
                    return CheckboxListTile(
                      title: Text(disc),
                      value: tempSelected.contains(disc),
                      onChanged: (bool? val) {
                        setStateDialog(() {
                          if (val == true) {
                            tempSelected.add(disc);
                          } else {
                            tempSelected.remove(disc);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    tempSelected.clear();
                    Navigator.pop(context, tempSelected);
                  },
                  child: const Text('Annulla'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, tempSelected);
                  },
                  child: const Text('Conferma'),
                ),
              ],
            );
          },
        );
      },
    ).then((result) {
      if (result != null && result is Set<String>) {
        setState(() {
          _selectedDisciplines.clear();
          _selectedDisciplines.addAll(result);
          _updateStream();
        });
      }
    });
  }

  // Dialog per il filtro Posizione
  void _openLocationFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController addressCtrl = TextEditingController(
          text: _enteredAddress ?? '',
        );

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> _searchAndSetCoordinates() async {
              final query = addressCtrl.text.trim();
              if (query.isNotEmpty) {
                try {
                  final locations = await locationFromAddress(query);
                  if (locations.isNotEmpty) {
                    final loc = locations.first;
                    setStateDialog(() {
                      _filterLat = loc.latitude;
                      _filterLng = loc.longitude;
                    });
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Indirizzo non trovato: $e')),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('Filtra per posizione'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: addressCtrl,
                      decoration: InputDecoration(
                        labelText: 'Inserisci punto di partenza',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _searchAndSetCoordinates,
                        ),
                      ),
                      onSubmitted: (_) => _searchAndSetCoordinates(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Raggio (km):'),
                        Expanded(
                          child: Slider(
                            value: _searchRadius,
                            min: 10,
                            max: 200,
                            divisions: 190,
                            label: '${_searchRadius.toStringAsFixed(0)} km',
                            onChanged: (value) {
                              setStateDialog(() {
                                _searchRadius = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _enteredAddress = null;
                      _filterLat = null;
                      _filterLng = null;
                      _searchRadius = 10.0;
                      _positionFilterActive = false;
                    });
                    _updateStream();
                    Navigator.pop(context);
                  },
                  child: const Text('Rimuovi filtro'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _enteredAddress = addressCtrl.text.trim();
                      if (_filterLat != null && _filterLng != null) {
                        _positionFilterActive = true;
                      } else {
                        _positionFilterActive = false;
                      }
                    });
                    _updateStream();
                    Navigator.pop(context);
                  },
                  child: const Text('Applica'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: buildBottomNavBar(context, 2),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Eventi'),
        backgroundColor: const Color(0xFFD8A739),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFD8A739),
        onPressed: () {
          showCreateEventGlobalDialog(context);
        },
        label: const Text('Crea Evento'),
      ),
      body: Column(
        children: [
          // Filtri (Sport a sinistra, Posizione a destra)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _openMultiDisciplineFilter,
                    icon: const Icon(
                      FontAwesomeIcons.personRunning,
                      size: 24,
                    ),
                    label: Text(
                      _selectedDisciplines.isEmpty
                          ? 'Sport'
                          : _selectedDisciplines.join(', '),
                      style: const TextStyle(fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEBB744),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _openLocationFilterDialog,
                    icon: const Icon(Icons.location_on),
                    label: Text(locationButtonLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEBB744),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<DocumentSnapshot>>(
              stream: _eventsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Errore nel caricamento.'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('Nessun evento disponibile.'));
                }

                List<DocumentSnapshot> docs = snapshot.data!;
                // Applichiamo il filtro di distanza lato client se attivo
                if (_positionFilterActive &&
                    _filterLat != null &&
                    _filterLng != null) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>?;
                    if (data == null) return false;
                    final lat = data['Location']?['Latitudine'] as double?;
                    final lng = data['Location']?['Longitudine'] as double?;
                    if (lat == null || lng == null) return false;
                    final distance = _computeDistanceInKm(
                      _filterLat!,
                      _filterLng!,
                      lat,
                      lng,
                    );
                    return distance <= _searchRadius;
                  }).toList();
                }

                final markers = <Marker>{};
                LatLng initialPos = const LatLng(45.0, 9.0);

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data == null) continue;
                  final lat = data['Location']?['Latitudine'] as double?;
                  final lng = data['Location']?['Longitudine'] as double?;
                  final title = data['Title'] ?? 'Evento';
                  String dateStr = '';
                  if (data['Date'] is Timestamp) {
                    final ts = data['Date'] as Timestamp;
                    dateStr = DateFormat('dd/MM/yyyy').format(ts.toDate());
                  }
                  if (lat != null && lng != null) {
                    markers.add(Marker(
                      markerId: MarkerId(doc.id),
                      position: LatLng(lat, lng),
                      infoWindow: InfoWindow(
                        title: title,
                        snippet: dateStr,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventDetailsPage(
                                eventData: data,
                                eventDoc: doc,
                              ),
                            ),
                          );
                        },
                      ),
                    ));
                    initialPos = LatLng(lat, lng);
                  }
                }

                return Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: initialPos,
                          zoom: 12,
                        ),
                        markers: markers,
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>?;
                          if (data == null) return const SizedBox();
                          final title = data['Title'] ?? 'Senza titolo';
                          final discipline =
                              data['Discipline'] ?? 'Disciplina?';
                          final desc = data['Description'] ?? '';
                          String dateStr = 'Data mancante';
                          if (data['Date'] is Timestamp) {
                            final ts = data['Date'] as Timestamp;
                            dateStr =
                                DateFormat('dd/MM/yyyy').format(ts.toDate());
                          }
                          final shortDesc = desc.length > 50
                              ? '${desc.substring(0, 50)}...'
                              : desc;

                          return Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              title: Text(title),
                              subtitle:
                                  Text('$discipline | $dateStr\n$shortDesc'),
                              onTap: () {
                                print(
                                    "[DEBUG] Evento cliccato in Eventi: $title");
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EventDetailsPage(
                                      eventData: data,
                                      eventDoc: docs[index],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ––––––– PROFILO (index=3) –––––––
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: buildBottomNavBar(context, 3),
      backgroundColor: const Color(0xFFEBB744),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Menù Profilo'),
        backgroundColor: const Color(0xFFD8A739),
        actions: [
          IconButton(
            onPressed: () async {
              // Logout Firebase e Google
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn().signOut();
            },
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          const Hero(
            tag: 'profile-pic',
            child: CircleAvatar(
              backgroundImage: AssetImage('assets/profile.jpg'),
              radius: 50,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profilo'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserProfilePage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('I Miei Eventi'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyEventsPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: buildBottomNavBar(context, 3),
      appBar: AppBar(
        title: const Text('Profilo'),
        backgroundColor: const Color(0xFFD8A739),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'Nome Utente',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Numero di Telefono',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Salva Modifiche'),
            ),
          ],
        ),
      ),
    );
  }
}

class MyEventsPage extends StatelessWidget {
  const MyEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: buildBottomNavBar(context, 3),
      appBar: AppBar(
        title: const Text('I Miei Eventi'),
        backgroundColor: const Color(0xFFD8A739),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('events').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Errore nel caricamento degli eventi.'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nessun evento disponibile.'));
          }

          var events = snapshot.data!.docs;
          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final data = events[index].data() as Map<String, dynamic>? ?? {};

              final title = data['Title'] ?? 'Senza titolo';
              final discipline = data['Discipline'] ?? 'Disciplina?';
              final orgName = data['Organizer Name'] ?? 'Organizzatore?';
              final orgNumber = data['Organizer Number'] ?? 'Numero?';
              final distance = data['Distance'] ?? '-';
              final diffLevel = data['Difficulty_Level'] ?? '-';
              final duration = data['Duration'] ?? '-';
              final cost = data['Participation_Cost'] ?? '-';
              final maxPart = data['Max_Participants'] ?? '-';
              final desc = data['Description'] ?? '-';
              final imageRef = data['Image'] ?? '(nessuna immagine)';
              final gpxRef = data['GPX Track'] ?? '(nessun GPX)';

              String dateStr = 'Data mancante';
              if (data['Date'] is Timestamp) {
                final ts = data['Date'] as Timestamp;
                dateStr = DateFormat('dd/MM/yyyy').format(ts.toDate());
              }

              String address = 'Luogo mancante';
              if (data['Location'] is Map) {
                final locMap = data['Location'] as Map<String, dynamic>;
                address = locMap['Indirizzo'] ?? 'Luogo mancante';
              } else if (data['Location'] is String) {
                address = data['Location'];
              }

              final info = '''
Titolo: $title
Disciplina: $discipline
Data: $dateStr
Luogo: $address
Organizzatore: $orgName ($orgNumber)
Partecipanti max: $maxPart
Costo: $cost
Durata: $duration
Difficoltà: $diffLevel
Distanza: $distance
Descrizione: $desc
Img: $imageRef
GPX: $gpxRef
''';

              return Card(
                child: ListTile(
                  title: Text(title),
                  subtitle: Text(info),
                  onTap: () {
                    print("[DEBUG] Evento cliccato in MyEvents: $title");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventDetailsPage(
                          eventData: data,
                          eventDoc: events[index],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ––––––– FINESTRA "CREA EVENTO" (DIALOG) CON MAPPA –––––––
void showCreateEventGlobalDialog(
  BuildContext context, {
  String? initialDiscipline,
}) {
  // Lista delle discipline
  const List<String> allDisciplines = [
    'E-MTB - MTB',
    'GRAVEL',
    'BICI DA STRADA',
    'TRAIL RUNNING',
    'ESCURSIONISMO',
  ];

  // Livelli di difficoltà
  const List<String> difficultyLevels = [
    'Facile',
    'Intermedio',
    'Difficile',
  ];

  // Controller per i campi
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final distanceController = TextEditingController();
  final durationController = TextEditingController();
  final gpxTrackController = TextEditingController();

  // Controller per la localizzazione
  final locationController = TextEditingController();
  double? chosenLat;
  double? chosenLng;

  // File selezionati
  XFile? selectedImageFile;
  XFile? selectedGPXFile;

  // Funzione per selezionare il file GPX
  Future<void> pickGPXFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpx'],
    );
    if (result != null && result.files.single.path != null) {
      selectedGPXFile = XFile(result.files.single.path!);
    }
  }

  // Funzione per selezionare un'immagine
  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      selectedImageFile = file;
    }
  }

  final organizerNameController =
      TextEditingController(text: 'Nome Organizzatore');
  final organizerNumberController = TextEditingController(text: '1234567890');
  bool showOrganizerNumber = false;

  DateTime? pickedDate;
  TimeOfDay? pickedTime;

  String? selectedDiscipline = initialDiscipline;
  String? selectedDifficulty;

  bool showAdditionalDetails = false;

  // ––– Funzione per selezionare la posizione su mappa –––
  Future<void> pickLocationMap(BuildContext ctx) async {
    // Posizione iniziale di default
    LatLng initialPosition = const LatLng(45.0, 7.0);
    LatLng? _pickedLocation;
    // Controller per la ricerca indirizzo
    final TextEditingController addressSearchController =
        TextEditingController();
    GoogleMapController? mapController;

    await showDialog(
      context: ctx,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            height: 500,
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                Future<void> _searchAddress() async {
                  final query = addressSearchController.text.trim();
                  if (query.isNotEmpty) {
                    try {
                      final locations = await locationFromAddress(query);
                      if (locations.isNotEmpty) {
                        final loc = locations.first;
                        setStateDialog(() {
                          _pickedLocation = LatLng(loc.latitude, loc.longitude);
                        });
                        if (mapController != null) {
                          mapController!.animateCamera(
                            CameraUpdate.newLatLng(_pickedLocation!),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text("Indirizzo non trovato")),
                        );
                      }
                    } catch (e) {
                      print("Errore nel geocoding: $e");
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content:
                                Text("Errore nella ricerca dell'indirizzo")),
                      );
                    }
                  }
                }

                return Column(
                  children: [
                    // Casella di testo per inserire l'indirizzo e pulsante di ricerca
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: addressSearchController,
                              decoration: const InputDecoration(
                                hintText: "Inserisci indirizzo",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _searchAddress,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GoogleMap(
                        onMapCreated: (controller) {
                          mapController = controller;
                        },
                        initialCameraPosition: CameraPosition(
                          target: initialPosition,
                          zoom: 12,
                        ),
                        onTap: (LatLng pos) {
                          setStateDialog(() {
                            _pickedLocation = pos;
                          });
                        },
                        markers: _pickedLocation != null
                            ? {
                                Marker(
                                  markerId: const MarkerId('picked'),
                                  position: _pickedLocation!,
                                )
                              }
                            : {},
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (_pickedLocation != null) {
                          chosenLat = _pickedLocation!.latitude;
                          chosenLng = _pickedLocation!.longitude;
                          locationController.text =
                              "Lat: ${chosenLat!.toStringAsFixed(4)}, Lng: ${chosenLng!.toStringAsFixed(4)}";
                        }
                        Navigator.pop(context);
                      },
                      child: const Text('Conferma posizione'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> createEvent() async {
    print("[DEBUG] In createEvent: title: ${titleController.text}");
    print(
        "[DEBUG] In createEvent: pickedDate: $pickedDate, pickedTime: $pickedTime");
    print("[DEBUG] In createEvent: selectedDiscipline: $selectedDiscipline");
    print("[DEBUG] In createEvent: location: ${locationController.text}");
    print("[DEBUG] In createEvent: description: ${descriptionController.text}");
    print(
        "[DEBUG] In createEvent: chosenLat: $chosenLat, chosenLng: $chosenLng");

    if (titleController.text.isNotEmpty &&
        pickedDate != null &&
        pickedTime != null &&
        selectedDiscipline != null &&
        locationController.text.isNotEmpty &&
        descriptionController.text.isNotEmpty &&
        chosenLat != null &&
        chosenLng != null) {
      try {
        String? imageUrl = '';
        String? gpxUrl = '';

        // Caricamento immagine su Firebase Storage (nella cartella "Immagini")
        if (selectedImageFile != null) {
          final fileName = path.basename(selectedImageFile!.path);
          final storageRef =
              FirebaseStorage.instance.ref().child('Immagini/$fileName');
          TaskSnapshot snapshot;
          if (kIsWeb) {
            final bytes = await selectedImageFile!.readAsBytes();
            snapshot = await storageRef.putData(bytes);
          } else {
            snapshot = await storageRef.putFile(File(selectedImageFile!.path));
          }
          imageUrl = await snapshot.ref.getDownloadURL();
          print("[DEBUG] Image uploaded: $imageUrl");
        }
        // Caricamento file GPX su Firebase Storage (nella cartella "GPX")
        if (selectedGPXFile != null) {
          final fileName = path.basename(selectedGPXFile!.path);
          final storageRef =
              FirebaseStorage.instance.ref().child('GPX/$fileName');
          TaskSnapshot snapshot;
          if (kIsWeb) {
            final bytes = await selectedGPXFile!.readAsBytes();
            snapshot = await storageRef.putData(bytes);
          } else {
            snapshot = await storageRef.putFile(File(selectedGPXFile!.path));
          }
          gpxUrl = await snapshot.ref.getDownloadURL();
          print("[DEBUG] GPX uploaded: $gpxUrl");
        }

        final eventData = {
          'Title': titleController.text,
          'Date': Timestamp.fromDate(DateTime(
            pickedDate!.year,
            pickedDate!.month,
            pickedDate!.day,
            pickedTime!.hour,
            pickedTime!.minute,
          )),
          'Location': {
            'Latitudine': chosenLat,
            'Longitudine': chosenLng,
            'Indirizzo': locationController.text,
          },
          'Description': descriptionController.text,
          'Discipline': selectedDiscipline ?? '',
          'Distance': distanceController.text,
          'Duration': durationController.text,
          'Difficulty_Level': selectedDifficulty ?? '-',
          'GPX Track': gpxUrl ?? gpxTrackController.text,
          'Organizer Name': organizerNameController.text,
          'Organizer Number':
              showOrganizerNumber ? organizerNumberController.text : '',
          'Image': imageUrl ?? '',
        };

        await FirebaseFirestore.instance
            .collection(selectedDiscipline!)
            .add(eventData);

        print("[DEBUG] Event created successfully.");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Evento creato con successo!')),
          );
        }

        // Reset dei campi
        titleController.clear();
        descriptionController.clear();
        distanceController.clear();
        durationController.clear();
        gpxTrackController.clear();
        locationController.clear();
        pickedDate = null;
        pickedTime = null;
        selectedDiscipline = null;
        selectedDifficulty = null;
        chosenLat = null;
        chosenLng = null;
      } catch (e) {
        print("[DEBUG] Error in createEvent: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Errore durante la creazione dell\'evento: $e')),
          );
        }
      }
    } else {
      print("[DEBUG] Missing required fields");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Compila correttamente tutti i campi, incluse data e luogo.')),
        );
      }
    }
  }

  Future<void> pickDateTime(
    BuildContext ctx,
    void Function(void Function()) setStateDialog,
  ) async {
    final chosenDate = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('it', 'IT'),
    );
    if (chosenDate != null) {
      final chosenTime = await showTimePicker(
        context: ctx,
        initialTime: TimeOfDay.now(),
      );
      if (chosenTime != null) {
        setStateDialog(() {
          pickedDate = chosenDate;
          pickedTime = chosenTime;
        });
      }
    }
  }

  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: StatefulBuilder(
          builder: (BuildContext ctx, setStateDialog) {
            final dateText = (pickedDate == null || pickedTime == null)
                ? ''
                : '${DateFormat('dd/MM/yyyy').format(pickedDate!)} ${pickedTime!.format(ctx)}';

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: MediaQuery.of(ctx).size.width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Titolo *'),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          hintText: 'Titolo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Descrizione *'),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          hintText: 'Descrizione',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Data e Ora *'),
                      TextField(
                        readOnly: true,
                        onTap: () => pickDateTime(ctx, setStateDialog),
                        controller: TextEditingController(text: dateText),
                        decoration: InputDecoration(
                          hintText: 'Data e Ora',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.date_range),
                            onPressed: () => pickDateTime(ctx, setStateDialog),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Luogo *'),
                      TextField(
                        readOnly: true,
                        onTap: () => pickLocationMap(ctx),
                        controller: locationController,
                        decoration: InputDecoration(
                          hintText: 'Seleziona Luogo (Mappa)',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.place),
                            onPressed: () => pickLocationMap(ctx),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Disciplina *'),
                      DropdownButton<String>(
                        value: selectedDiscipline,
                        hint: const Text('Seleziona disciplina'),
                        isExpanded: true,
                        onChanged: (String? newValue) {
                          setStateDialog(() {
                            selectedDiscipline = newValue;
                          });
                        },
                        items: allDisciplines.map<DropdownMenuItem<String>>(
                          (String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          },
                        ).toList(),
                      ),
                      const SizedBox(height: 16),
                      if (showAdditionalDetails) ...[
                        const Text('Distanza'),
                        TextField(
                          controller: distanceController,
                          decoration: const InputDecoration(
                            hintText: 'Es. 10 km',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Durata'),
                        TextField(
                          controller: durationController,
                          decoration: const InputDecoration(
                            hintText: 'Es. 2h',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Livello di Difficoltà'),
                        DropdownButton<String>(
                          value: selectedDifficulty,
                          hint: const Text('Seleziona il livello'),
                          isExpanded: true,
                          onChanged: (value) {
                            setStateDialog(() {
                              selectedDifficulty = value;
                            });
                          },
                          items: difficultyLevels
                              .map<DropdownMenuItem<String>>((String val) {
                            return DropdownMenuItem<String>(
                              value: val,
                              child: Text(val),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        const Text('Traccia GPX'),
                        TextField(
                          controller: gpxTrackController,
                          decoration: const InputDecoration(
                            hintText: 'Link o reference GPX',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await pickGPXFile();
                            setStateDialog(() {});
                          },
                          child: const Text('Carica File GPX'),
                        ),
                        if (selectedGPXFile != null)
                          Text(
                              'File GPX selezionato: ${selectedGPXFile!.name}'),
                        const SizedBox(height: 16),
                        const Text('Immagine'),
                        ElevatedButton(
                          onPressed: () async {
                            await pickImage();
                            setStateDialog(() {});
                          },
                          child: const Text('Carica Immagine'),
                        ),
                        if (selectedImageFile != null)
                          Text(
                              'Immagine selezionata: ${selectedImageFile!.name}'),
                      ],
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () {
                            setStateDialog(() {
                              showAdditionalDetails = !showAdditionalDetails;
                            });
                          },
                          child: Text(showAdditionalDetails
                              ? 'Nascondi Dettagli'
                              : 'Aggiungi Ulteriori Dettagli'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Organizzatore (automatico)'),
                      TextField(
                        controller: organizerNameController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          hintText: 'Nome Organizzatore',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: organizerNumberController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                hintText: 'Telefono',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          Checkbox(
                            value: showOrganizerNumber,
                            onChanged: (bool? value) {
                              setStateDialog(() {
                                showOrganizerNumber = value ?? false;
                              });
                            },
                          ),
                          const Text('Mostra Numero'),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Annulla'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () async {
                              await createEvent();
                              Navigator.pop(dialogContext);
                            },
                            child: const Text('Crea Evento'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

// ––––––– PAGINA DETTAGLI EVENTO (AGGIORNATA) –––––––
class EventDetailsPage extends StatelessWidget {
  final Map<String, dynamic> eventData;
  final DocumentSnapshot? eventDoc;

  const EventDetailsPage({
    super.key,
    required this.eventData,
    required this.eventDoc,
  });

  // Funzione per mostrare il dialog con la mappa che indica il luogo
  void _showMapDialog(
      BuildContext context, double lat, double lng, String address) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(lat, lng),
                      zoom: 14,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('location'),
                        position: LatLng(lat, lng),
                      ),
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    address,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Chiudi'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = eventData['Title'] ?? 'Senza titolo';
    final discipline = eventData['Discipline'] ?? 'Disciplina?';
    final orgName = eventData['Organizer Name'] ?? 'Organizzatore?';
    final orgNumber = eventData['Organizer Number'] ?? 'Numero?';
    final distance = eventData['Distance'] ?? '-';
    final diffLevel = eventData['Difficulty_Level'] ?? '-';
    final duration = eventData['Duration'] ?? '-';
    final cost = eventData['Participation_Cost'] ?? '-';
    final maxPart = eventData['Max_Participants'] ?? '-';
    final desc = eventData['Description'] ?? 'Nessuna descrizione disponibile.';
    final imageRef = eventData['Image'] ?? '(nessuna immagine)';
    final gpxRef = eventData['GPX Track'] ?? '(nessun GPX)';

    String dateStr = 'Data mancante';
    if (eventData['Date'] is Timestamp) {
      final ts = eventData['Date'] as Timestamp;
      dateStr = DateFormat('dd/MM/yyyy').format(ts.toDate());
    }

    String address = 'Luogo mancante';
    double? latitude;
    double? longitude;
    if (eventData['Location'] is Map) {
      final locMap = eventData['Location'] as Map<String, dynamic>;
      address = locMap['Indirizzo'] ?? 'Luogo mancante';
      latitude = locMap['Latitudine'] as double?;
      longitude = locMap['Longitudine'] as double?;
    } else if (eventData['Location'] is String) {
      address = eventData['Location'];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFFD8A739),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Titolo e descrizione in cima, centrati
            Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  desc,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Informazioni principali'),
            _buildInfoRow('Disciplina', discipline),
            _buildInfoRow('Data', dateStr),
            // La riga "Luogo" è ora cliccabile: al tap viene aperta la mappa
            GestureDetector(
              onTap: () {
                if (latitude != null && longitude != null) {
                  _showMapDialog(context, latitude, longitude, address);
                }
              },
              child: _buildInfoRow('Luogo', address),
            ),
            _buildInfoRow('Organizzatore', '$orgName ($orgNumber)'),
            _buildInfoRow('Partecipanti max', maxPart),
            _buildInfoRow('Costo', cost),
            const SizedBox(height: 16),
            _buildSectionTitle('Dettagli dell\'evento'),
            _buildInfoRow('Durata', duration),
            _buildInfoRow('Difficoltà', diffLevel),
            _buildInfoRow('Distanza', distance),
            const SizedBox(height: 16),
            _buildSectionTitle('Risorse'),
            _buildResourceRow('Immagine', imageRef, 'Apri immagine', () {
              // Placeholder per l'apertura dell'immagine
            }),
            _buildResourceRow('GPX', gpxRef, 'Scarica GPX', () {
              // Placeholder per il download del file GPX
            }),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  // Gestione della partecipazione: aggiunge il nome completo dell'utente
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Devi essere loggato per partecipare")),
                    );
                    return;
                  }
                  final userDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.uid)
                      .get();
                  if (!userDoc.exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Profilo utente non trovato.")),
                    );
                    return;
                  }
                  final nome = userDoc.data()?['nome'] ?? '';
                  final cognome = userDoc.data()?['cognome'] ?? '';
                  final fullName = '$nome $cognome';
                  if (eventDoc == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text("Errore: documento evento non trovato.")),
                    );
                    return;
                  }
                  try {
                    await eventDoc!.reference.update({
                      'partecipanti': FieldValue.arrayUnion([fullName])
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Hai confermato la tua presenza!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Errore durante la partecipazione: $e')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('Partecipa'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:'),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceRow(
    String label,
    String value,
    String buttonText,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text('$label: $value')),
          ElevatedButton(
            onPressed: onPressed,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}
