import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Carrega a biblioteca nativa nenures_core (MLS + convite).
  await RustLib.init();
  runApp(const ProviderScope(child: NenuresApp()));
}
