/// Verwaltung am Geraet: welche Sendungsarten und Abholorte erscheinen, wie
/// sie im Werk heissen, und an welches gemeinsame Postfach gemeldet wird.
/// Erreichbar ueber langen Druck auf das Logo, geschuetzt durch einen Code.
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api_service.dart';
import '../config.dart';
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
  late final TextEditingController _host =
      TextEditingController(text: widget.settings.smtp.host);
  late final TextEditingController _port =
      TextEditingController(text: '${widget.settings.smtp.port}');
  late final TextEditingController _user =
      TextEditingController(text: widget.settings.smtp.user);
  late final TextEditingController _password =
      TextEditingController(text: widget.settings.smtp.password);
  late final TextEditingController _from =
      TextEditingController(text: widget.settings.smtp.fromAddress);
  late final TextEditingController _fromName =
      TextEditingController(text: widget.settings.smtp.fromName);

  bool _testing = false;

  /// Auf einer Bildschirmtastatur vertippt man sich leicht, und ein
  /// verdecktes Passwort verraet den Fehler nicht.
  bool _showPassword = false;

  /// Anzahl der Personen in der gerade gueltigen Liste.
  int _staffCount = 0;

  L10n get _l => L10n(widget.locale.value);

  @override
  void initState() {
    super.initState();
    _countStaff();
  }

  Future<void> _countStaff() async {
    final service = ApiService()..staffCsv = widget.settings.staffCsv;
    try {
      final staff = await service.staff();
      if (mounted) setState(() => _staffCount = staff.length);
    } on ApiException {
      if (mounted) setState(() => _staffCount = 0);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _mailbox,
      _host,
      _port,
      _user,
      _password,
      _from,
      _fromName,
    ]) {
      controller.dispose();
    }
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
          if (wide)
            TextButton.icon(
              onPressed: _confirmReset,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.restart_alt, size: 24),
              label: Text(
                _l.t('admin.reset'),
                style: const TextStyle(fontSize: 17),
              ),
            )
          else
            IconButton(
              tooltip: _l.t('admin.reset'),
              color: Colors.white,
              iconSize: 26,
              onPressed: _confirmReset,
              icon: const Icon(Icons.restart_alt),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _staffCard(),
            const SizedBox(height: 20),
            _smtpCard(),
            const SizedBox(height: 20),
            _mailboxCard(),
            const SizedBox(height: 20),
            _locationCard(),
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
            const SizedBox(height: 24),
            // Damit im Zweifel ablesbar ist, welche Fassung auf dem Geraet
            // wirklich laeuft -- eine gescheiterte Aktualisierung sieht man
            // dem Bildschirm sonst nicht an.
            const Center(
              child: Text(
                'Version ${AppConfig.appVersion}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
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

  Widget _field(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    bool numeric = false,
    Widget? suffix,
    void Function(String)? onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          autocorrect: false,
          keyboardType: numeric
              ? TextInputType.number
              : TextInputType.emailAddress,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: suffix,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: onChanged,
        ),
      );

  /// Zugangsdaten liegen im geschuetzten Speicher der App, nicht im APK.
  Widget _smtpCard() {
    // Nebeneinander bleibt fuer den Text zu wenig Platz -- auf schmalen
    // Bildschirmen brach er sonst Buchstabe fuer Buchstabe um.
    final roomy = MediaQuery.sizeOf(context).width >= 600;

    final sslSwitch = SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        _l.t('admin.smtp.ssl'),
        style: const TextStyle(fontSize: 16),
      ),
      value: widget.settings.smtp.ssl,
      onChanged: (v) =>
          setState(() => widget.settings.updateSmtp((s) => s.copyWith(ssl: v))),
    );

    final portField = _field(
      _l.t('admin.smtp.port'),
      _port,
      numeric: true,
      onChanged: (v) => widget.settings.updateSmtp(
        (s) => s.copyWith(port: int.tryParse(v) ?? s.port),
      ),
    );

    final testButton = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      onPressed: _testing ? null : _sendTest,
      icon: _testing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.outgoing_mail, size: 22),
      label: Text(
        _l.t('admin.smtp.test'),
        style: const TextStyle(fontSize: 17),
      ),
    );

    final testHint = Text(
      _l.t('admin.smtp.test.target'),
      style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
    );

    return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(_l.t('admin.smtp')),
            const SizedBox(height: 6),
            Text(
              _l.t('admin.smtp.hint'),
              style: const TextStyle(fontSize: 15, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            _field(_l.t('admin.smtp.host'), _host,
                onChanged: (v) =>
                    widget.settings.updateSmtp((s) => s.copyWith(host: v))),
            if (roomy)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 160, child: portField),
                  const SizedBox(width: 16),
                  Expanded(child: sslSwitch),
                ],
              )
            else ...[
              portField,
              sslSwitch,
            ],
            _field(_l.t('admin.smtp.user'), _user,
                onChanged: (v) =>
                    widget.settings.updateSmtp((s) => s.copyWith(user: v))),
            _field(
              _l.t('admin.smtp.password'),
              _password,
              obscure: !_showPassword,
              suffix: IconButton(
                tooltip: _l.t('admin.smtp.show'),
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _showPassword = !_showPassword),
              ),
              onChanged: (v) =>
                  widget.settings.updateSmtp((s) => s.copyWith(password: v)),
            ),
            _field(_l.t('admin.smtp.from'), _from,
                onChanged: (v) => widget.settings
                    .updateSmtp((s) => s.copyWith(fromAddress: v))),
            _field(_l.t('admin.smtp.fromname'), _fromName,
                onChanged: (v) => widget.settings
                    .updateSmtp((s) => s.copyWith(fromName: v))),
            if (roomy)
              Row(
                children: [
                  Expanded(child: testHint),
                  const SizedBox(width: 16),
                  testButton,
                ],
              )
            else ...[
              testHint,
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: testButton),
            ],
          ],
        ),
      );
  }

  /// Ein weiterer Standort liest hier seine eigene Liste ein -- ohne dass
  /// jemand ein eigenes APK bauen muss.
  Widget _staffCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(_l.t('admin.staff')),
            const SizedBox(height: 6),
            Text(
              _l.t(
                widget.settings.hasOwnStaffList
                    ? 'admin.staff.own'
                    : 'admin.staff.builtin',
                args: {'count': '$_staffCount'},
              ),
              style: const TextStyle(fontSize: 16, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            Text(
              _l.t('admin.staff.hint'),
              style: const TextStyle(fontSize: 15, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                  onPressed: _importStaff,
                  icon: const Icon(Icons.upload_file, size: 22),
                  label: Text(
                    _l.t('admin.staff.import'),
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
                if (widget.settings.hasOwnStaffList)
                  TextButton.icon(
                    onPressed: () async {
                      setState(() => widget.settings.setStaffCsv(null));
                      await _countStaff();
                    },
                    icon: const Icon(Icons.restore, size: 22),
                    label: Text(
                      _l.t('admin.staff.reset'),
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _locationCard() => _card(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _l.t('admin.location.ask'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            _l.t('admin.location.hint'),
            style: const TextStyle(fontSize: 15, color: AppColors.inkSoft),
          ),
          value: widget.settings.askLocation,
          onChanged: (value) =>
              setState(() => widget.settings.setAskLocation(value)),
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
      hint: _l.t('admin.pin.short'),
      controller: controller,
      numeric: true,
    );
    controller.dispose();
    if (saved == null) return;

    // Ein zu kurzer Code waere schnell erraten -- und ein leerer wuerde die
    // Verwaltung fuer jeden oeffnen, der lange aufs Logo drueckt.
    if (saved.trim().length < kMinPinLength) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l.t('admin.pin.short'))),
      );
      return;
    }
    setState(() => widget.settings.setPin(saved.trim()));
  }

  /// Liest eine CSV vom Geraet ein. Eine Datei ohne brauchbare Zeile wird
  /// abgewiesen -- sonst stuende der Empfang vor einer leeren Suche, und
  /// niemand wuesste warum.
  Future<void> _importStaff() async {
    // Android filtert .csv ueber die Endung nicht zuverlaessig, deshalb
    // ohne Einschraenkung waehlen lassen.
    final file = await FilePicker.pickFile();
    if (!mounted || file == null) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;

    // allowMalformed, damit eine aus Excel exportierte Datei mit fremder
    // Zeichenkodierung nicht am ersten Umlaut scheitert.
    final text = utf8.decode(bytes, allowMalformed: true);
    final parsed = employeesFromCsv(text);
    final messenger = ScaffoldMessenger.of(context);

    if (parsed.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(_l.t('admin.staff.empty'))),
      );
      return;
    }

    setState(() {
      widget.settings.setStaffCsv(text);
      _staffCount = parsed.length;
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _l.t('admin.staff.ok', args: {'count': '${parsed.length}'}),
        ),
      ),
    );
  }

  /// Prueft den Zugang, ohne dass jemand eine echte Sendung erfinden muss.
  Future<void> _sendTest() async {
    setState(() => _testing = true);
    final smtp = widget.settings.smtp;
    final messenger = ScaffoldMessenger.of(context);

    String result;
    try {
      await ApiService().sendMail(
        MailContent(
          to: [smtp.fromAddress.trim()],
          cc: const [],
          subject: '${_l.t('app.title')} – ${_l.t('admin.smtp.test')}',
          body: _l.t('admin.smtp.test.ok'),
        ),
        smtp,
      );
      result = _l.t('admin.smtp.test.ok');
    } on ApiException catch (e) {
      result = '${_l.t(e.messageKey)}\n${e.detail ?? ''}'.trim();
    }

    if (!mounted) return;
    setState(() => _testing = false);
    messenger.showSnackBar(
      SnackBar(content: Text(result), duration: const Duration(seconds: 6)),
    );
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
