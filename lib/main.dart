import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/product_provider.dart';
import 'providers/report_provider.dart';
import 'providers/shift_provider.dart';
import 'providers/transaction_history_provider.dart';
import 'providers/user_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inisialisasi data locale untuk format tanggal Indonesia (id_ID)
  await initializeDateFormatting('id_ID');
  runApp(const PosApp());
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => TransactionHistoryProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ShiftProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'POS Kasir',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// Menentukan halaman awal berdasarkan status login
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await context.read<AuthProvider>().checkLogin();
    if (mounted) setState(() => _checked = true);
  }

  // Nyalakan polling notifikasi saat login, matikan saat logout
  void _syncNotificationPolling(bool isLoggedIn) {
    final provider = context.read<NotificationProvider>();
    if (isLoggedIn) {
      provider.startPolling();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) provider.refresh();
      });
    } else {
      provider.stopPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (!_checked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    _syncNotificationPolling(authProvider.isLoggedIn);

    return authProvider.isLoggedIn
        ? const DashboardScreen()
        : const LoginScreen();
  }
}
