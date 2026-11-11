import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/content_repository.dart';
import 'data/local_store.dart';
import 'data/remote.dart';
import 'state/app_state.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Remote? remote;
  if (AppConfig.hasBackend) {
    // La session est conservée de façon sécurisée par supabase_flutter et
    // renouvelée automatiquement.
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);
    remote = Remote(Supabase.instance.client);
  }

  final store = await LocalStore.open();
  final state = AppState(store: store, content: ContentRepository(store), remote: remote);
  runApp(SiffletApp(state: state));
  await state.init();
}
