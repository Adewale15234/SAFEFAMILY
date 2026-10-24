import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const chatEmerald = Color(0xFF16D9A0);
const chatBackground = Color(0xFF0B1110);
const chatSurface = Color(0xFF151F1C);
const chatMuted = Color(0xFF9AAEA5);

class FamilyChatPage extends StatefulWidget {
  const FamilyChatPage({super.key});

  @override
  State<FamilyChatPage> createState() => _FamilyChatPageState();
}

class _FamilyChatPageState extends State<FamilyChatPage> {
  final controller = TextEditingController();
  final searchController = TextEditingController();
  final scrollController = ScrollController();

  late final Future<String?> familyIdFuture;

  bool showSearch = false;
  bool sending = false;
  String searchQuery = '';
  String? replyText;
  String? replySender;

  @override
  void initState() {
    super.initState();
    familyIdFuture = _resolveFamilyId();
  }

  @override
  void dispose() {
    controller.dispose();
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<String?> _resolveFamilyId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data();
    if (!userDoc.exists || userData == null || userData['status'] != 'active') {
      return null;
    }

    final familyId = userData['familyId'];
    if (familyId is! String || familyId.isEmpty) return null;

    final memberDoc = await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(user.uid)
        .get();

    final memberData = memberDoc.data();
    if (!memberDoc.exists ||
        memberData == null ||
        memberData['status'] != 'active') {
      return null;
    }

    return familyId;
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: chatSurface,
      ),
    );
  }

  Future<void> _sendMessage({
    String? overrideText,
    String type = 'text',
  }) async {
    final text = (overrideText ?? controller.text).trim();
    if (text.isEmpty || sending) return;

    if (text.length > 4000) {
      _notify('Messages must be 4,000 characters or fewer.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _notify('Sign in before sending messages.');
      return;
    }

    setState(() => sending = true);

    try {
      final familyId = await familyIdFuture;
      if (familyId == null) {
        _notify('Join a family before using family chat.');
        return;
      }

      final memberRef = FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('members')
          .doc(user.uid);

      final member = await memberRef.get();
      final memberData = member.data();

      if (!member.exists ||
          memberData == null ||
          memberData['status'] != 'active') {
        _notify('Your active family membership could not be verified.');
        return;
      }

      final storedName = memberData['displayName'];
      final name = (storedName is String && storedName.trim().isNotEmpty)
          ? storedName.trim()
          : (user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : (user.email?.split('@').first ?? 'Family member'));

      await FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('chatMessages')
          .add({
            'senderId': user.uid,
            'senderName': name,
            'text': text,
            'type': type,
            'createdAt': FieldValue.serverTimestamp(),
            'replyToText': replyText ?? '',
            'replyToSender': replySender ?? '',
          });

      if (!mounted) return;
      if (overrideText == null) controller.clear();

      setState(() {
        replyText = null;
        replySender = null;
      });
    } on FirebaseException catch (error) {
      _notify(
        error.code == 'permission-denied'
            ? 'Firebase denied this message. Check that the new chat rules are deployed and your membership is active.'
            : 'Message could not be sent (${error.code}). Check your connection and try again.',
      );
    } catch (_) {
      _notify('Something went wrong while sending the message.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _insertEmoji(String emoji) {
    final value = controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;

    final newText = value.text.replaceRange(start, end, emoji);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _showEmojiPicker() async {
    const emojis = [
      '😀',
      '😂',
      '🥰',
      '😊',
      '🙏',
      '❤️',
      '👍',
      '👎',
      '🎉',
      '👏',
      '🤝',
      '💚',
      '😢',
      '😮',
      '🔥',
      '✅',
      '🏠',
      '👨‍👩‍👧‍👦',
      '📍',
      '🛡️',
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: chatSurface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: emojis.map((emoji) {
              return InkWell(
                onTap: () {
                  _insertEmoji(emoji);
                  Navigator.pop(sheetContext);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Text(emoji, style: const TextStyle(fontSize: 27)),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _openTools() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: chatSurface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Communication tools',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined, color: chatEmerald),
              title: const Text('Send safety check-in'),
              subtitle: const Text('Tell your family you are safe'),
              onTap: () => Navigator.pop(sheetContext, 'safety'),
            ),
            ListTile(
              leading: const Icon(
                Icons.emoji_emotions_outlined,
                color: chatEmerald,
              ),
              title: const Text('Insert emoji'),
              onTap: () => Navigator.pop(sheetContext, 'emoji'),
            ),
            ListTile(
              leading: const Icon(Icons.mic_none_rounded, color: chatMuted),
              title: const Text('Voice messages'),
              subtitle: const Text('Not implemented yet'),
              onTap: () => Navigator.pop(sheetContext, 'voice'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'safety') {
      await _sendMessage(
        overrideText: '✅ I have checked in and I am safe.',
        type: 'safety',
      );
    } else if (action == 'emoji') {
      await _showEmojiPicker();
    } else if (action == 'voice') {
      _notify(
        'Voice recording will be added after text messaging is verified.',
      );
    }
  }

  Future<void> _openMessageActions(Map<String, dynamic> data) async {
    final text = data['text'] as String? ?? '';
    final sender = data['senderName'] as String? ?? 'Family member';

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: chatSurface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: chatEmerald),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(sheetContext, 'reply'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: chatEmerald),
              title: const Text('Copy message'),
              onTap: () => Navigator.pop(sheetContext, 'copy'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: text));
      _notify('Message copied.');
    } else if (action == 'reply') {
      setState(() {
        replyText = text;
        replySender = sender;
      });
    }
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return 'Sending…';
    return TimeOfDay.fromDateTime(value.toDate()).format(context);
  }

  Widget _buildMessageList(String familyId) {
    final stream = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('chatMessages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots(includeMetadataChanges: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Messages unavailable',
            subtitle: 'Check your connection, family membership and deployed Firestore rules.',
            actionLabel: 'Retry',
            onAction: () => setState(() {}),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: chatEmerald),
          );
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final query = searchQuery.trim().toLowerCase();
          return query.isEmpty ||
              (data['text'] as String? ?? '').toLowerCase().contains(query) ||
              (data['senderName'] as String? ?? '').toLowerCase().contains(
                query,
              );
        }).toList();

        if (docs.isEmpty) {
          return _EmptyState(
            icon: searchQuery.isEmpty
                ? Icons.forum_outlined
                : Icons.search_off_rounded,
            title: searchQuery.isEmpty
                ? 'Start your family conversation'
                : 'No messages found',
            subtitle: searchQuery.isEmpty
                ? 'Send a message or a safety check-in to get started.'
                : 'Try another name or search term.',
          );
        }

        return ListView.builder(
          controller: scrollController,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final user = FirebaseAuth.instance.currentUser;
            final mine = data['senderId'] == user?.uid;

            return _MessageBubble(
              data: data,
              mine: mine,
              pending: doc.metadata.hasPendingWrites,
              time: _formatTime(data['createdAt']),
              onLongPress: () => _openMessageActions(data),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chatBackground,
      appBar: AppBar(
        backgroundColor: chatBackground,
        titleSpacing: 0,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: Color(0xFF254238),
              child: Icon(Icons.family_restroom_rounded, color: chatEmerald),
            ),
            SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adewale Manchi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'SAFEFAMILY • Family chat',
                    style: TextStyle(fontSize: 11, color: chatMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search messages',
            onPressed: () {
              setState(() {
                showSearch = !showSearch;
                searchQuery = '';
                searchController.clear();
              });
            },
            icon: Icon(showSearch ? Icons.close_rounded : Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Communication tools',
            onPressed: _openTools,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: FutureBuilder<String?>(
        future: familyIdFuture,
        builder: (context, familySnapshot) {
          if (familySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: chatEmerald),
            );
          }

          final familyId = familySnapshot.data;
          if (familyId == null) {
            return const _EmptyState(
              icon: Icons.family_restroom_rounded,
              title: 'Join your family first',
              subtitle: 'Sign in and make sure your account has an active family membership before opening family chat.',
            );
          }

          return Column(
            children: [
              if (showSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                  child: TextField(
                    controller: searchController,
                    autofocus: true,
                    onChanged: (value) => setState(() => searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search messages or people…',
                      prefixIcon: const Icon(Icons.search, color: chatEmerald),
                      suffixIcon: IconButton(
                        onPressed: () {
                          searchController.clear();
                          setState(() => searchQuery = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                      filled: true,
                      fillColor: chatSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              Container(
                margin: const EdgeInsets.fromLTRB(14, 8, 14, 5),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: chatSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: chatEmerald.withValues(alpha: .14)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: chatEmerald, size: 21),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Family-only chat. Messages sync through Firebase when connected.',
                        style: TextStyle(
                          color: chatMuted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildMessageList(familyId)),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                decoration: const BoxDecoration(
                  color: chatSurface,
                  border: Border(top: BorderSide(color: Color(0xFF26332E))),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (replyText != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: chatBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.reply, color: chatEmerald),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Replying to $replySender\n$replyText',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              IconButton(
                                onPressed: () => setState(() {
                                  replyText = null;
                                  replySender = null;
                                }),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'More tools',
                            onPressed: _openTools,
                            color: chatEmerald,
                            icon: const Icon(Icons.add_circle_outline_rounded),
                          ),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              minLines: 1,
                              maxLines: 5,
                              maxLength: 4000,
                              textCapitalization: TextCapitalization.sentences,
                              onSubmitted: (_) => _sendMessage(),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: 'Write a message…',
                                hintStyle: const TextStyle(
                                  color: chatMuted,
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: chatBackground,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Insert emoji',
                            onPressed: _showEmojiPicker,
                            icon: const Icon(Icons.emoji_emotions_outlined),
                            color: chatEmerald,
                          ),
                          const SizedBox(width: 2),
                          IconButton.filled(
                            tooltip: 'Send message',
                            onPressed: sending ? null : _sendMessage,
                            style: IconButton.styleFrom(
                              backgroundColor: chatEmerald,
                              foregroundColor: chatBackground,
                              minimumSize: const Size(46, 46),
                            ),
                            icon: sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool mine;
  final bool pending;
  final String time;
  final VoidCallback onLongPress;

  const _MessageBubble({
    required this.data,
    required this.mine,
    required this.pending,
    required this.time,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final sender = data['senderName'] as String? ?? 'Family member';
    final text = data['text'] as String? ?? '';
    final type = data['type'] as String? ?? 'text';
    final replyText = data['replyToText'] as String? ?? '';
    final replySender = data['replyToSender'] as String? ?? '';

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * .82,
          ),
          margin: const EdgeInsets.only(bottom: 11),
          padding: const EdgeInsets.fromLTRB(13, 10, 12, 8),
          decoration: BoxDecoration(
            color: type == 'safety'
                ? const Color(0xFF234A37)
                : mine
                ? const Color(0xFF174B38)
                : chatSurface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(17),
              topRight: const Radius.circular(17),
              bottomLeft: Radius.circular(mine ? 17 : 4),
              bottomRight: Radius.circular(mine ? 4 : 17),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    sender,
                    style: const TextStyle(
                      color: chatEmerald,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (replyText.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$replySender: $replyText',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: chatMuted),
                  ),
                ),
              if (type == 'safety')
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield, color: chatEmerald, size: 16),
                      SizedBox(width: 5),
                      Text(
                        'SAFETY CHECK-IN',
                        style: TextStyle(
                          color: chatEmerald,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(text, style: const TextStyle(fontSize: 14, height: 1.45)),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: const TextStyle(
                        color: Color(0xFFB3C6BD),
                        fontSize: 10,
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        pending ? Icons.schedule_rounded : Icons.check_rounded,
                        size: 14,
                        color: pending ? chatMuted : chatEmerald,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: chatSurface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 42, color: chatEmerald),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: chatMuted, height: 1.5),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
