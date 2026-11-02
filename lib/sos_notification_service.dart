import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SosNotificationService {
  SosNotificationService._();

  static final SosNotificationService instance = SosNotificationService._();

  static const String _channelId = 'safefamily_sos_alerts';
  static const String _channelName = 'SAFEFAMILY SOS alerts';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _registrationSubscription;
  StreamSubscription<String>? _unregisteredFidSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _familySosSubscription;

  Future<void>? _initializationFuture;
  bool _initialized = false;

  String? _listeningFamilyId;
  bool _hasInitialEmergencySnapshot = false;

  // Prevent duplicate notifications for the same emergency record.
  final Set<String> _knownEmergencyIds = <String>{};

  /// Initializes notification support once.
  Future<void> initialize() {
    return _initializationFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    if (_initialized) return;

    _initialized = true;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      await _localNotifications.initialize(
        settings: const InitializationSettings(android: androidSettings),
      );

      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Urgent family emergency alerts',
        importance: Importance.max,
        playSound: true,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await androidPlugin?.createNotificationChannel(channel);

      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Display Firebase push messages received while the app is in
      // the foreground. Background delivery requires a configured sender.
      _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
        (message) {
          unawaited(_showForegroundMessage(message));
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('SAFEFAMILY foreground message error: $error');
        },
      );

      // Firebase Messaging installation registration events.
      _registrationSubscription = _messaging.onRegistered.listen(
        (fid) {
          unawaited(_saveFid(fid));
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('SAFEFAMILY registration event failed: $error');
        },
      );

      _unregisteredFidSubscription = _messaging.onUnregistered.listen(
        (fid) {
          unawaited(_removeFid(fid));
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('SAFEFAMILY unregistration event failed: $error');
        },
      );

      _authSubscription = _auth.authStateChanges().listen(
        (user) {
          if (user != null) {
            unawaited(_registerCurrentDevice());
          } else {
            unawaited(stopListeningToFamilySos());
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('SAFEFAMILY authentication listener failed: $error');
        },
      );

      await _registerCurrentDevice();
    } catch (error, stackTrace) {
      // Notification setup must not prevent SAFEFAMILY from opening.
      debugPrint('SAFEFAMILY notification setup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Registers this installation with Firebase Messaging.
  ///
  /// Registration alone does not send SOS notifications.
  Future<void> _registerCurrentDevice() async {
    try {
      if (_auth.currentUser == null) return;

      final settings = await _messaging.getNotificationSettings();

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('SAFEFAMILY notifications are disabled on this device.');
        return;
      }

      await _messaging.register();
    } catch (error, stackTrace) {
      debugPrint('SAFEFAMILY device registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Saves the Firebase installation ID under the signed-in user's account.
  Future<void> _saveFid(String fid) async {
    final user = _auth.currentUser;
    if (user == null || fid.isEmpty) return;

    final deviceId = base64Url.encode(utf8.encode(fid)).replaceAll('=', '');

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .set({
            'fid': fid,
            'platform': defaultTargetPlatform.name,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      debugPrint('SAFEFAMILY device registration saved.');
    } catch (error, stackTrace) {
      debugPrint('Could not save SAFEFAMILY device registration: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Removes a Firebase installation ID when it is unregistered.
  Future<void> _removeFid(String fid) async {
    final user = _auth.currentUser;
    if (user == null || fid.isEmpty) return;

    final deviceId = base64Url.encode(utf8.encode(fid)).replaceAll('=', '');

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .delete();

      debugPrint('SAFEFAMILY device registration removed.');
    } catch (error, stackTrace) {
      debugPrint('Could not remove SAFEFAMILY device registration: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Listens for new SOS records in the specified family.
  ///
  /// The receiving app must be running and connected to Firestore for this
  /// listener to display alerts. Existing records are ignored at startup.
  Future<void> listenToFamilySos(String familyId) async {
    final user = _auth.currentUser;
    final cleanedFamilyId = familyId.trim();

    if (user == null || cleanedFamilyId.isEmpty) {
      debugPrint(
        'SAFEFAMILY SOS listener not started: user or family ID is missing.',
      );
      return;
    }

    await initialize();

    // The account could have changed while initialization was running.
    if (_auth.currentUser?.uid != user.uid) return;

    if (_listeningFamilyId == cleanedFamilyId &&
        _familySosSubscription != null) {
      return;
    }

    await _familySosSubscription?.cancel();

    _familySosSubscription = null;
    _listeningFamilyId = cleanedFamilyId;
    _hasInitialEmergencySnapshot = false;
    _knownEmergencyIds.clear();

    debugPrint('SAFEFAMILY starting family SOS listener.');

    _familySosSubscription = _firestore
        .collection('families')
        .doc(cleanedFamilyId)
        .collection('emergencies')
        .snapshots()
        .listen(
          (snapshot) {
            // Seed existing records without replaying old alerts.
            if (!_hasInitialEmergencySnapshot) {
              _hasInitialEmergencySnapshot = true;

              for (final document in snapshot.docs) {
                _knownEmergencyIds.add(document.id);
              }

              debugPrint('SAFEFAMILY SOS listener is ready.');
              return;
            }

            for (final change in snapshot.docChanges) {
              if (change.type != DocumentChangeType.added) continue;

              final document = change.doc;

              // Claim this alert ID once so subsequent snapshots cannot notify
              // twice.
              if (!_knownEmergencyIds.add(document.id)) continue;

              final Map<String, dynamic>? documentData = document.data();
              if (documentData == null) continue;

              final data = documentData;
              final senderUid = data['createdBy'];

              // Do not notify the person who created the SOS.
              if (senderUid is! String ||
                  senderUid.isEmpty ||
                  senderUid == _auth.currentUser?.uid) {
                continue;
              }

              // Avoid comparing server timestamps with the device clock.
              if (data['status'] != 'active') continue;

              unawaited(_showFamilySos(document.id, data));
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('SAFEFAMILY family SOS listener failed: $error');
            debugPrintStack(stackTrace: stackTrace);
          },
        );
  }

  /// Stops listening to a family's emergency records.
  Future<void> stopListeningToFamilySos() async {
    final subscription = _familySosSubscription;

    _familySosSubscription = null;
    _listeningFamilyId = null;
    _hasInitialEmergencySnapshot = false;
    _knownEmergencyIds.clear();

    await subscription?.cancel();

    debugPrint('SAFEFAMILY family SOS listener stopped.');
  }

  /// Displays a local notification for an incoming family SOS.
  Future<void> _showFamilySos(String alertId, Map<String, dynamic> data) async {
    final rawSenderName = data['senderName'];
    final senderName =
        rawSenderName is String && rawSenderName.trim().isNotEmpty
        ? rawSenderName.trim()
        : 'A family member';

    final rawMessage = data['message'];
    final message = rawMessage is String ? rawMessage.trim() : '';

    final body = message.isNotEmpty
        ? '$senderName: $message'
        : '$senderName has triggered an emergency SOS. Open SAFEFAMILY now.';

    try {
      final rawId = alertId.hashCode & 0x7fffffff;
      final notificationId = rawId == 0 ? 1 : rawId;

      await _localNotifications.show(
        id: notificationId,
        title: 'SAFEFAMILY SOS ALERT',
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Urgent family emergency alerts',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
          ),
        ),
        payload: alertId,
      );

      debugPrint('SAFEFAMILY displayed incoming SOS alert: $alertId');
    } catch (error, stackTrace) {
      debugPrint('Could not display incoming family SOS: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Displays a Firebase push message received while the app is open.
  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;

    try {
      final rawId = message.messageId?.hashCode ?? 0;
      final notificationId = rawId & 0x7fffffff;

      await _localNotifications.show(
        id: notificationId == 0 ? 1 : notificationId,
        title: notification?.title ?? 'SAFEFAMILY SOS ALERT',
        body:
            notification?.body ??
            'A family emergency alert has been received. '
                'Open SAFEFAMILY for details.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Urgent family emergency alerts',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
          ),
        ),
        payload: message.data['alertId']?.toString(),
      );

      debugPrint('SAFEFAMILY displayed a foreground push notification.');
    } catch (error, stackTrace) {
      debugPrint('Could not display foreground SOS notification: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Cancels subscriptions when the service is explicitly disposed.
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _registrationSubscription?.cancel();
    await _unregisteredFidSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await stopListeningToFamilySos();

    _authSubscription = null;
    _registrationSubscription = null;
    _unregisteredFidSubscription = null;
    _foregroundMessageSubscription = null;

    _initialized = false;
    _initializationFuture = null;
  }
}
