import 'package:slow_mail/mail/mail.dart';
import 'package:slow_mail/utils/common_import.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:slow_mail/utils/android_notifyer.dart';

class ConnectionProvider extends ChangeNotifier with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? subscription;

  bool _netAvailable = true;

  bool get netAvailable => _netAvailable;
  set netAvailable(bool value) {
    if (value == _netAvailable) return;
    _netAvailable = value;
    notifyListeners();
  }

  Future<void> setNetAvailable(bool value) async {
    AppLogger.log("Set netAvailable $value");
    if (value == _netAvailable) return;
    if (value) {
      try {
        await NavService.navKey.currentContext?.read<EmailProvider>().resumeConnection();
      } catch (e) {
        AppLogger.log("Resume: $e");
      }
      _netAvailable = value;
      notifyListeners();
      await AndroidNotifyer().runQueuedNotificationTask();
    } else {
      await NavService.navKey.currentContext?.read<EmailProvider>().pauseConnection();
      _netAvailable = value;
      notifyListeners();
    }
  }

  ConnectionProvider() {
    //Connectivity().checkConnectivity().then((List<ConnectivityResult> result) => checkNetworkState(result));
    WidgetsBinding.instance.addObserver(this);
    subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) async {
      await checkNetworkState(result);
    });
  }

  Future<void> enableNetIfConnected() async {
    checkNetworkState(await Connectivity().checkConnectivity());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    AppLogger.log(state);
    switch (state) {
      case AppLifecycleState.resumed:
        //await setNetAvailable(true);
        await checkNetworkState(await Connectivity().checkConnectivity());
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        await setNetAvailable(false);
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    subscription?.cancel();
    super.dispose();
  }

  Future<void> checkNetworkState(List<ConnectivityResult> connectivityResult) async {
    await setNetAvailable(connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.ethernet) ||
        connectivityResult.contains(ConnectivityResult.vpn) ||
        connectivityResult.contains(ConnectivityResult.other));
  }
}
