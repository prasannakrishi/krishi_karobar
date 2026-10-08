import 'package:flutter/material.dart';

import '../../../common/widgets/app_scaffold.dart';
import '../../../services/session_service.dart';
import '../../../utils/helper/helper_widgets.dart';
import '../../navigarion/screen/main_screen.dart';
import 'login/login_screen.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<SessionRestoreResult> _restore;
  bool _messageShown = false;

  @override
  void initState() {
    super.initState();
    _restore = SessionService.instance.restore();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SessionRestoreResult>(
      future: _restore,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const UAppScaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final result = snapshot.data;

        if (result != null && result.isRestored) {
          return const MainScreen();
        }

        final message = result?.message;

        if (message != null && !_messageShown) {
          _messageShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            warningSnackBar(title: 'Please sign in', message: message);
          });
        }

        return const LoginScreen();
      },
    );
  }
}
