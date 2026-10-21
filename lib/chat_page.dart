
import 'package:flutter/material.dart';

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
  final scrollController = ScrollController();

  String selectedLanguage = 'English';
  String selectedConversation = 'Family Circle';
  bool showTranslator = false;

  final List<_ChatMessage> messages = [
    _ChatMessage(
      sender: 'Amina',
      text: 'Hello family! Has everyone arrived safely?',
      time: '2:15 PM',
      mine: false,
      demo: true,
    ),
    _ChatMessage(
      sender: 'You',
      text: 'I am fine. How is everybody?',
      time: '2:17 PM',
      mine: true,
      demo: true,
    ),
    _ChatMessage(
      sender: 'Baba',
      text: 'Please remember to check in when you arrive.',
      time: '2:19 PM',
      mine: false,
      demo: true,
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void sendMessage() {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add(
        _ChatMessage(
          sender: 'You',
          text: text,
          time: TimeOfDay.now().format(context),
          mine: true,
          demo: false,
        ),
      );
      controller.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void openTranslator() {
    final translationController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: chatSurface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.translate_rounded,
                        color: chatEmerald, size: 27),
                    SizedBox(width: 10),
                    Text(
                      'Family translator',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Prepare a message for someone who speaks another language.',
                  style: TextStyle(color: chatMuted, height: 1.5),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: selectedLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Message language',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'English',
                      child: Text('English'),
                    ),
                    DropdownMenuItem(
                      value: 'Yoruba',
                      child: Text('Yoruba'),
                    ),
                    DropdownMenuItem(
                      value: 'Hausa',
                      child: Text('Hausa'),
                    ),
                    DropdownMenuItem(
                      value: 'Igbo',
                      child: Text('Igbo'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => selectedLanguage = value);
                      setState(() => selectedLanguage = value);
                    }
                  },
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: translationController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Type your message in English',
                    hintText: 'Example: I have arrived safely.',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: chatBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          color: chatEmerald, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Translation requires a translation service. This preview does not translate text or generate speech yet.',
                          style: TextStyle(
                            color: chatMuted,
                            height: 1.45,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final text = translationController.text.trim();
                      if (text.isEmpty) {
                        notify('Enter a message first.');
                        return;
                      }

                      Navigator.pop(sheetContext);
                      controller.text = text;
                      notify(
                        'Draft prepared. Translation and voice sending are not connected yet.',
                      );
                    },
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Use as chat draft'),
                    style: FilledButton.styleFrom(
                      backgroundColor: chatEmerald,
                      foregroundColor: chatBackground,
                      padding: const EdgeInsets.all(15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(translationController.dispose);
  }

  void openVoicePreview() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Voice messages'),
        content: const Text(
          'Voice recording, speech recognition and spoken translation need microphone permissions and speech services. No audio is being recorded in this preview.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void openContacts() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: chatSurface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'People & conversations',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a conversation type.',
                style: TextStyle(color: chatMuted),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF254238),
                  child: Icon(Icons.family_restroom,
                      color: chatEmerald),
                ),
                title: const Text('Family Circle'),
                subtitle: const Text('Family group preview'),
                onTap: () {
                  setState(() => selectedConversation = 'Family Circle');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF254238),
                  child: Icon(Icons.person_add_alt_1,
                      color: chatEmerald),
                ),
                title: const Text('Invite a trusted contact'),
                subtitle: const Text('External invitations are not connected'),
                onTap: () {
                  Navigator.pop(context);
                  notify(
                    'Contact invitations require accounts and a secure messaging backend.',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showInformation() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Family Chat'),
        content: const Text(
          'This is an interactive local prototype. Messages you type stay in memory and are lost when the app closes. Other phones cannot receive them yet. Translation, voice recording, account invitations and secure online messaging are not active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chatBackground,
      appBar: AppBar(
        backgroundColor: chatBackground,
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 21,
              backgroundColor: Color(0xFF254238),
              child: Icon(Icons.family_restroom_rounded,
                  color: chatEmerald),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedConversation,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Local preview Â· Not connected',
                    style: TextStyle(
                      fontSize: 11,
                      color: chatMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'People and conversations',
            onPressed: openContacts,
            icon: const Icon(Icons.people_alt_outlined),
          ),
          IconButton(
            tooltip: 'Information',
            onPressed: showInformation,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF202B27),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: chatEmerald.withValues(alpha: 0.15),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.offline_bolt_rounded,
                    color: chatEmerald, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Prototype mode: messages are not sent to other devices.',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
            child: Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.translate_rounded,
                    label: 'Translate',
                    onTap: openTranslator,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.mic_none_rounded,
                    label: 'Voice note',
                    onTap: openVoicePreview,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Invite',
                    onTap: openContacts,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF26332E), height: 16),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return _MessageBubble(message: message);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: const BoxDecoration(
              color: chatSurface,
              border: Border(
                top: BorderSide(color: Color(0xFF26332E)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Voice note preview',
                    onPressed: openVoicePreview,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    color: chatEmerald,
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Write a message...',
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
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Add message to local preview',
                    onPressed: sendMessage,
                    style: IconButton.styleFrom(
                      backgroundColor: chatEmerald,
                      foregroundColor: chatBackground,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String sender;
  final String text;
  final String time;
  final bool mine;
  final bool demo;

  const _ChatMessage({
    required this.sender,
    required this.text,
    required this.time,
    required this.mine,
    this.demo = false,
  });
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(13, 10, 12, 8),
        decoration: BoxDecoration(
          color: message.mine
              ? const Color(0xFF174B38)
              : chatSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(message.mine ? 17 : 4),
            bottomRight: Radius.circular(message.mine ? 4 : 17),
          ),
          border: message.demo
              ? Border.all(color: Colors.white.withValues(alpha: 0.04))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.mine) ...[
              Text(
                message.sender,
                style: const TextStyle(
                  color: chatEmerald,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
            ],
            Text(
              message.text,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.time,
                    style: const TextStyle(
                      color: Color(0xFFB3C6BD),
                      fontSize: 10,
                    ),
                  ),
                  if (message.mine) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.done_all_rounded,
                        size: 14, color: chatEmerald),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: chatSurface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
          child: Column(
            children: [
              Icon(icon, color: chatEmerald, size: 22),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

