import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _memberEmerald = Color(0xFF16D9A0);
const Color _memberBackground = Color(0xFF0B1110);
const Color _memberSurface = Color(0xFF151F1C);
const Color _memberMuted = Color(0xFF9AAEA5);
const Color _memberBorder = Color(0xFF293831);
const Color _memberDanger = Color(0xFFFF6675);

class FamilyMember {
  final String id;
  final String name;
  final String relationship;
  final String phone;
  final String age;

  const FamilyMember({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    required this.age,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'relationship': relationship,
    'phone': phone,
    'age': age,
  };

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      relationship: json['relationship'] as String? ?? 'Other',
      phone: json['phone'] as String? ?? '',
      age: json['age'] as String? ?? '',
    );
  }
}

class FamilyMembersSection extends StatefulWidget {
  const FamilyMembersSection({super.key});

  @override
  State<FamilyMembersSection> createState() => _FamilyMembersSectionState();
}

class _FamilyMembersSectionState extends State<FamilyMembersSection> {
  List<FamilyMember> _members = [];
  bool _loading = true;
  bool _busy = false;

  String get _storageKey {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'local';
    return 'safefamily_members_v1_$uid';
  }

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_storageKey);

      if (saved != null) {
        final decoded = jsonDecode(saved);
        if (decoded is List) {
          _members = decoded
              .whereType<Map>()
              .map(
                (item) =>
                    FamilyMember.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        }
      }
    } catch (error) {
      debugPrint('Could not load family members: $error');
      if (mounted) {
        _notify('Could not load saved family members.');
      }
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<bool> _saveMembers(List<FamilyMember> updated) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _storageKey,
        jsonEncode(updated.map((member) => member.toJson()).toList()),
      );

      if (saved && mounted) {
        setState(() => _members = updated);
      }
      return saved;
    } catch (error) {
      debugPrint('Could not save family members: $error');
      return false;
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEditor({FamilyMember? existing}) async {
    if (_busy) return;

    final result = await showDialog<FamilyMember>(
      context: context,
      builder: (_) => FamilyMemberEditor(existing: existing),
    );

    if (result == null || !mounted) return;

    setState(() => _busy = true);

    final updated = [..._members];
    final index = updated.indexWhere((member) => member.id == result.id);

    if (index >= 0) {
      updated[index] = result;
    } else {
      updated.add(result);
    }

    final saved = await _saveMembers(updated);

    if (mounted) {
      setState(() => _busy = false);
      _notify(
        saved
            ? (index >= 0
                  ? 'Family member updated.'
                  : 'Family member added successfully.')
            : 'Could not save the member. Please try again.',
      );
    }
  }

  Future<void> _removeMember(FamilyMember member) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _memberSurface,
        title: const Text('Remove family member?'),
        content: Text(
          'Remove ${member.name} from this device’s family list? '
          'This does not delete a separate account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _memberDanger,
              foregroundColor: _memberBackground,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final updated = _members.where((item) => item.id != member.id).toList();
    final saved = await _saveMembers(updated);

    if (mounted) {
      setState(() => _busy = false);
      _notify(
        saved
            ? 'Family member removed.'
            : 'Could not remove the member. Please try again.',
      );
    }
  }

  IconData _relationshipIcon(String relationship) {
    switch (relationship) {
      case 'Wife':
        return Icons.favorite_rounded;
      case 'Husband':
        return Icons.favorite_rounded;
      case 'Son':
      case 'Daughter':
      case 'Child':
        return Icons.child_care_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'FAMILY MEMBERS',
                style: TextStyle(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              '${_members.length} ${_members.length == 1 ? 'member' : 'members'}',
              style: const TextStyle(color: _memberMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: _loading || _busy ? null : () => _openEditor(),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add family member'),
            style: FilledButton.styleFrom(
              backgroundColor: _memberEmerald,
              foregroundColor: _memberBackground,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: _memberEmerald),
            ),
          )
        else if (_members.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _memberSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _memberBorder),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.family_restroom_rounded,
                  size: 42,
                  color: _memberEmerald,
                ),
                SizedBox(height: 12),
                Text(
                  'Your family list starts here',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  'Add your wives, children, and other family members '
                  'to keep their details together on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _memberMuted, height: 1.5),
                ),
              ],
            ),
          )
        else
          ..._members.map(
            (member) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _memberSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _memberBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _memberEmerald.withValues(alpha: 0.13),
                    child: Icon(
                      _relationshipIcon(member.relationship),
                      color: _memberEmerald,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            member.relationship,
                            if (member.age.isNotEmpty) 'Age ${member.age}',
                          ].join(' • '),
                          style: const TextStyle(
                            color: _memberMuted,
                            fontSize: 12,
                          ),
                        ),
                        if (member.phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            member.phone,
                            style: const TextStyle(
                              color: _memberMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: (action) {
                      if (action == 'edit') {
                        _openEditor(existing: member);
                      } else if (action == 'remove') {
                        _removeMember(member);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit member')),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove member'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (_busy) const LinearProgressIndicator(color: _memberEmerald),
        const SizedBox(height: 10),
        const Text(
          'Member details are saved locally on this device. '
          'They are not yet shared with other phones.',
          style: TextStyle(color: _memberMuted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }
}

class FamilyMemberEditor extends StatefulWidget {
  final FamilyMember? existing;

  const FamilyMemberEditor({super.key, this.existing});

  @override
  State<FamilyMemberEditor> createState() => _FamilyMemberEditorState();
}

class _FamilyMemberEditorState extends State<FamilyMemberEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _ageController;
  late String _relationship;

  static const List<String> _relationships = [
    'Wife',
    'Husband',
    'Son',
    'Daughter',
    'Child',
    'Mother',
    'Father',
    'Brother',
    'Sister',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _phoneController = TextEditingController(text: existing?.phone ?? '');
    _ageController = TextEditingController(text: existing?.age ?? '');
    _relationship =
        existing != null && _relationships.contains(existing.relationship)
        ? existing.relationship
        : 'Wife';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: _memberBackground,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _memberBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _memberEmerald, width: 1.5),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.existing;
    final member = FamilyMember(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      relationship: _relationship,
      phone: _phoneController.text.trim(),
      age: _ageController.text.trim(),
    );

    Navigator.of(context).pop(member);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _memberSurface,
      title: Text(
        widget.existing == null ? 'Add family member' : 'Edit family member',
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration('Full name *', Icons.person_outline),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter the member’s name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _relationship,
                  isExpanded: true,
                  decoration: _decoration(
                    'Relationship',
                    Icons.family_restroom_rounded,
                  ),
                  items: _relationships
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _relationship = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _decoration(
                    'Phone number (optional)',
                    Icons.phone_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: _decoration(
                    'Age (optional)',
                    Icons.cake_outlined,
                  ),
                  validator: (value) {
                    final age = value?.trim() ?? '';
                    if (age.isNotEmpty) {
                      final parsed = int.tryParse(age);
                      if (parsed == null || parsed < 0 || parsed > 120) {
                        return 'Enter an age between 0 and 120.';
                      }
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: _memberEmerald,
            foregroundColor: _memberBackground,
          ),
          child: const Text('Save member'),
        ),
      ],
    );
  }
}
