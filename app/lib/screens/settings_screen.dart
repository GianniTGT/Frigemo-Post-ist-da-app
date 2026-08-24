/// Verwaltung am Geraet: welche Sendungsarten und Abholorte erscheinen, wie
/// sie im Werk heissen, und an welches gemeinsame Postfach gemeldet wird.
/// Erreichbar ueber langen Druck auf das Logo, geschuetzt durch einen Code.
library;

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../main.dart' show AppColors;
import '../settings.dart';

class SettingsScreen extends StatefulWidget {
  final TerminalSettings settings;
  final LocaleController locale;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.locale,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _mailbox =
      TextEditingController(text: widget.settings.sharedMailbox);

  L10n get _l => L10n(widget.locale.value);

  @override
  void dispose() {
    _mailbox.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final kinds = _section(
      title: _l.t('admin.kinds'),
      entries: widget.settings.kinds,
      prefix: 'kind',
      allowUrgent: true,
      onChange: widget.settings.updateKind,
      onAdd: (label, urgent) =>
          widget.settings.addKind(label, urgent: urgent),
    );

    final locations = _section(
      title: _l.t('admin.locations'),
      entries: widget.settings.locations,
      prefix: 'location',
      allowUrgent: false,
      onChange: widget.settings.updateLocation,
      onAdd: (label, _) => widget.settings.addLocation(label),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        toolbarHeight: 72,
        title: Text(
          _l.t('admin.title'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: _confirmReset,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.restart_alt, size: 24),
            label: Text(
              _l.t('admin.reset'),
              style: const TextStyle(fontSize: 17),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _mailboxCard(),
            const SizedBox(height: 20),
            if (wide)
              // Auf dem Tablet quer nebeneinander -- so bleibt beides ohne
              // Scrollen im Blick.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: kinds),
                    const SizedBox(width: 20),
                    Expanded(child: locations),
                  ],
                ),
              )
            else ...[
              kinds,
              const SizedBox(height: 20),
              locations,
            ],
            const SizedBox(height: 20),
            _pinCard(),
          ],
        ),
      ),
    );
  }

  // --- Bausteine -----------------------------------------------------------

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      );

  Widget _heading(String text) => Text(
        text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      );

  Widget _mailboxCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(_l.t('admin.mailbox')),
            const SizedBox(height: 6),
            Text(
              _l.t('admin.mailbox.hint'),
              style: const TextStyle(fontSize: 15, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mailbox,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: const TextStyle(fontSize: 19),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                hintText: 'name@frigemo.ch',
              ),
              onChanged: (value) =>
                  setState(() => widget.settings.setSharedMailbox(value)),
            ),
          ],
        ),
      );

  Widget _section({
    required String title,
    required List<OptionEntry> entries,
    required String prefix,
    required bool allowUrgent,
    required void Function(String, OptionEntry Function(OptionEntry)) onChange,
    required String Function(String, bool) onAdd,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _heading(title)),
              TextButton.icon(
                onPressed: () => _addEntry(title, allowUrgent, onAdd),
                icon: const Icon(Icons.add, size: 24),
                label: Text(
                  _l.t('admin.add'),
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final entry in entries)
            _entryRow(entry, prefix, allowUrgent, onChange),
          const SizedBox(height: 8),
          Text(
            _l.t('admin.builtin.hint'),
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _entryRow(
    OptionEntry entry,
    String prefix,
    bool allowUrgent,
    void Function(String, OptionEntry Function(OptionEntry)) onChange,
  ) {
    final label = widget.settings.labelOf(entry, _l, prefix);
    final renamed = (entry.customLabel?.trim() ?? '').isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Switch(
            value: entry.visible,
            onChanged: (value) => _setVisible(entry, value, onChange),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: entry.visible ? AppColors.ink : AppColors.inkSoft,
                  ),
                ),
                if (renamed && entry.isBuiltIn)
                  Text(
                    _l.t('$prefix.${entry.id}'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.inkSoft,
                    ),
                  ),
              ],
            ),
          ),
          if (allowUrgent)
            IconButton(
              tooltip: _l.t('admin.urgent'),
              onPressed: () =>
                  setState(() => onChange(entry.id, (e) => e.copyWith(urgent: !e.urgent))),
              icon: Icon(
                entry.urgent
                    ? Icons.priority_high
                    : Icons.low_priority_outlined,
                size: 26,
                color: entry.urgent ? AppColors.alert : AppColors.inkSoft,
              ),
            ),
          IconButton(
            tooltip: _l.t('admin.name'),
            onPressed: () => _renameEntry(entry, prefix, onChange),
            icon: const Icon(Icons.edit_outlined, size: 26),
          ),
          if (!entry.isBuiltIn)
            IconButton(
              tooltip: _l.t('admin.delete'),
              onPressed: () =>
                  setState(() => widget.settings.remove(entry.id)),
              icon: const Icon(
                Icons.delete_outline,
                size: 26,
                color: AppColors.danger,
              ),
            ),
        ],
      ),
    );
  }

  Widget _pinCard() => _card(
        child: Row(
          children: [
            Expanded(child: _heading(_l.t('admin.pin.change'))),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              onPressed: _changePin,
              child: Text(
                _l.t('admin.pin.change'),
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
      );

  // --- Aktionen ------------------------------------------------------------

  /// Der letzte sichtbare Eintrag darf nicht verschwinden -- sonst stuende
  /// der Empfang vor einer leeren Auswahl.
  void _setVisible(
    OptionEntry entry,
    bool value,
    void Function(String, OptionEntry Function(OptionEntry)) onChange,
  ) {
    if (!value) {
      final list = widget.settings.kinds.any((e) => e.id == entry.id)
          ? widget.settings.visibleKinds
          : widget.settings.visibleLocations;
      if (list.length <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l.t('admin.empty'))),
        );
        return;
      }
    }
    setState(() => onChange(entry.id, (e) => e.copyWith(visible: value)));
  }

  Future<void> _renameEntry(
    OptionEntry entry,
    String prefix,
    void Function(String, OptionEntry Function(OptionEntry)) onChange,
  ) async {
    final controller =
        TextEditingController(text: entry.customLabel ?? '');
    final saved = await _textDialog(
      title: _l.t('admin.name'),
      hint: entry.isBuiltIn
          ? _l.t('$prefix.${entry.id}')
          : _l.t('admin.name.hint'),
      controller: controller,
    );
    controller.dispose();
    if (saved == null) return;

    setState(() {
      onChange(
        entry.id,
        (e) => e.copyWith(customLabel: saved.trim().isEmpty ? null : saved.trim()),
      );
    });
  }

  Future<void> _addEntry(
    String title,
    bool allowUrgent,
    String Function(String, bool) onAdd,
  ) async {
    final controller = TextEditingController();
    final saved = await _textDialog(
      title: title,
      hint: _l.t('admin.name'),
      controller: controller,
    );
    controller.dispose();
    if (saved == null || saved.trim().isEmpty) return;
    setState(() => onAdd(saved.trim(), false));
  }

  Future<void> _changePin() async {
    final controller = TextEditingController(text: widget.settings.pin);
    final saved = await _textDialog(
      title: _l.t('admin.pin.change'),
      hint: kDefaultPin,
      controller: controller,
      numeric: true,
    );
    controller.dispose();
    if (saved == null || saved.trim().isEmpty) return;
    setState(() => widget.settings.setPin(saved.trim()));
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(_l.t('admin.reset')),
        content: Text(
          _l.t('admin.builtin.hint'),
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_l.t('close'), style: const TextStyle(fontSize: 17)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_l.t('admin.reset'),
                style: const TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        widget.settings.resetToDefaults();
        _mailbox.text = widget.settings.sharedMailbox;
      });
    }
  }

  Future<String?> _textDialog({
    required String title,
    required String hint,
    required TextEditingController controller,
    bool numeric = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: numeric ? TextInputType.number : TextInputType.text,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_l.t('close'), style: const TextStyle(fontSize: 17)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child:
                Text(_l.t('admin.save'), style: const TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }
}
