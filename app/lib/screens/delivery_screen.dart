import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_service.dart';
import '../config.dart';
import '../l10n.dart';
import '../main.dart' show AppColors;
import '../settings.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class DeliveryScreen extends StatefulWidget {
  final LocaleController locale;
  final TerminalSettings settings;

  const DeliveryScreen({
    super.key,
    required this.locale,
    required this.settings,
  });

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  /// Steht "Andere" auf der Kachel, muss der Fahrer sagen koennen, von wem
  /// die Sendung ist -- sonst meldet das Terminal nur "Andere".
  final TextEditingController _otherCarrierCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  CarrierOption? _carrier;
  Employee? _recipient;
  int _quantity = 1;
  String? _kind;
  String? _location;

  List<Employee> _results = const [];
  bool _searching = false;
  bool _searchFailed = false;
  bool _submitting = false;
  bool _success = false;

  /// Auf der Sendung steht kein Name. Bewusst gewaehlt, nicht bloss "noch
  /// nichts ausgewaehlt" -- sonst ginge eine Meldung schon durch, weil
  /// jemand die Suche vergessen hat.
  bool _unknownRecipient = false;

  /// Der Fahrer hat einen Namen vom Etikett uebernommen, der nicht in der
  /// Liste steht. Die Meldung geht dann ans gemeinsame Postfach -- aber mit
  /// diesem Namen, statt ihn wegzuwerfen.
  String? _freeName;

  /// Gescannte Sendungsnummer. Leer heisst: nicht gescannt -- der Scan ist
  /// freiwillig und haelt den Sendeknopf nicht auf.
  String _tracking = '';

  Timer? _debounce;
  Timer? _idle;
  Timer? _successTimer;

  L10n get _l => L10n(widget.locale.value);

  /// Erster sichtbarer Eintrag, falls nichts gewaehlt ist oder die Auswahl
  /// inzwischen ausgeblendet wurde.
  OptionEntry _current(List<OptionEntry> visible, String? id) {
    for (final entry in visible) {
      if (entry.id == id) return entry;
    }
    return visible.first;
  }

  OptionEntry get _kindEntry => _current(widget.settings.visibleKinds, _kind);
  OptionEntry get _locationEntry =>
      _current(widget.settings.visibleLocations, _location);
  bool get _ready =>
      _carrier != null &&
      _carrierLabel.isNotEmpty &&
      (_recipient != null || _unknownRecipient || _freeName != null) &&
      !_submitting;

  /// Bei "Andere" zaehlt, was der Fahrer eingetippt hat. Bleibt es leer,
  /// bleibt der Sendeknopf gesperrt -- eine Meldung "von Andere" hilft am
  /// Empfang niemandem weiter.
  String get _carrierLabel {
    final carrier = _carrier;
    if (carrier == null) return '';
    if (carrier.id != 'other') return carrier.label;
    return _otherCarrierCtrl.text.trim();
  }

  void _onOtherCarrierChanged() {
    _touch();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _api.staffCsv = widget.settings.staffCsv;
    _searchCtrl.addListener(_onSearchChanged);
    // Der Sendeknopf haengt am Inhalt dieses Feldes.
    _otherCarrierCtrl.addListener(_onOtherCarrierChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _idle?.cancel();
    _successTimer?.cancel();
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    _otherCarrierCtrl.removeListener(_onOtherCarrierChanged);
    _otherCarrierCtrl.dispose();
    _searchFocus.dispose();
    _api.dispose();
    super.dispose();
  }

  // --- Leerlauf: Formular zurücksetzen, wenn niemand mehr davorsteht ----

  void _touch() {
    _idle?.cancel();
    if (_carrier == null &&
        _recipient == null &&
        !_unknownRecipient &&
        _freeName == null &&
        _tracking.isEmpty &&
        _searchCtrl.text.isEmpty) {
      return;
    }
    _idle = Timer(AppConfig.idleTimeout, () {
      if (mounted && !_submitting) _reset();
    });
  }

  // --- Empfängersuche --------------------------------------------------

  void _onSearchChanged() {
    // Sobald wieder getippt wird, ist die alte Auswahl ungültig.
    if (_recipient != null || _unknownRecipient || _freeName != null) {
      setState(() {
        _recipient = null;
        _unknownRecipient = false;
        _freeName = null;
      });
    }

    _touch();
    _debounce?.cancel();

    final query = _searchCtrl.text.trim();
    if (query.length < AppConfig.minSearchChars) {
      setState(() {
        _results = const [];
        _searching = false;
        _searchFailed = false;
      });
      return;
    }

    setState(() => _searching = true);
    _debounce = Timer(AppConfig.searchDebounce, () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    try {
      final found = await _api.searchEmployees(query);
      if (!mounted || _searchCtrl.text.trim() != query) return;
      setState(() {
        _results = found;
        _searching = false;
        _searchFailed = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _searching = false;
        _searchFailed = true;
      });
    }
  }

  void _selectRecipient(Employee employee) {
    _searchFocus.unfocus();
    setState(() {
      _recipient = employee;
      _results = const [];
      // Listener würde die Auswahl sofort wieder löschen – deshalb erst
      // abhängen, Text setzen, dann wieder anhängen.
      _searchCtrl.removeListener(_onSearchChanged);
      _searchCtrl.text = employee.name;
      _searchCtrl.addListener(_onSearchChanged);
    });
    _touch();
  }

  void _clearRecipient() {
    setState(() {
      _recipient = null;
      _results = const [];
      _searchCtrl.removeListener(_onSearchChanged);
      _searchCtrl.clear();
      _searchCtrl.addListener(_onSearchChanged);
    });
    _searchFocus.requestFocus();
    _touch();
  }

  // --- Senden ----------------------------------------------------------

  Future<void> _submit() async {
    if (!_ready) return;
    setState(() => _submitting = true);
    _idle?.cancel();

    final draft = DeliveryDraft(
      carrierLabel: _carrierLabel,
      recipient: _recipient,
      recipientName: _freeName,
      quantity: _quantity,
      kindLabel: widget.settings.labelOf(_kindEntry, _l, 'kind'),
      locationLabel: widget.settings.askLocation
          ? widget.settings.labelOf(_locationEntry, _l, 'location')
          : null,
      urgent: _kindEntry.urgent,
      note: _noteCtrl.text.trim(),
      trackingCode: _tracking,
      terminalName: widget.settings.terminalName,
      terminalLang: widget.locale.value,
    );

    try {
      await _api.submitDelivery(
        draft,
        smtp: widget.settings.smtp,
        sharedMailbox: widget.settings.sharedMailbox,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _success = true;
      });
      _successTimer?.cancel();
      _successTimer = Timer(AppConfig.successDuration, () {
        if (mounted) _reset();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(e);
    }
  }

  void _showError(ApiException error) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        icon: Icon(
          error.kind == ApiErrorKind.mailFailed
              ? Icons.mark_email_unread_outlined
              : Icons.error_outline,
          size: 48,
          color: error.kind == ApiErrorKind.mailFailed
              ? AppColors.alert
              : AppColors.danger,
        ),
        title: Text(
          _l.t('error.title'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          _l.t(error.messageKey),
          style: const TextStyle(fontSize: 18, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_l.t('close'), style: const TextStyle(fontSize: 18)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _submit();
            },
            child: Text(_l.t('retry'), style: const TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  void _reset() {
    _idle?.cancel();
    _successTimer?.cancel();
    // Sonst findet der naechste Fahrer die Sprache des vorigen vor.
    widget.locale.value = LocaleController.fromCode(AppConfig.defaultLanguage);
    setState(() {
      _carrier = null;
      _recipient = null;
      _quantity = 1;
      _unknownRecipient = false;
      _freeName = null;
      _tracking = '';
      _kind = null;
      _location = null;
      _results = const [];
      _searching = false;
      _searchFailed = false;
      _success = false;
      _searchCtrl.removeListener(_onSearchChanged);
      _searchCtrl.clear();
      _searchCtrl.addListener(_onSearchChanged);
      _noteCtrl.clear();
      _otherCarrierCtrl.removeListener(_onOtherCarrierChanged);
      _otherCarrierCtrl.clear();
      _otherCarrierCtrl.addListener(_onOtherCarrierChanged);
    });
  }

  void _toggleLanguage() {
    widget.locale.toggle();
    _touch();
  }

  // --- Verwaltung ------------------------------------------------------

  Future<void> _openSettings() async {
    _idle?.cancel();

    // Ohne vergebenen Code laesst sich die Verwaltung nicht schuetzen --
    // dann wird zuerst einer festgelegt.
    final settingUp = !widget.settings.hasPin;
    final entered = await _askPin(settingUp: settingUp);
    if (!mounted || entered == null) return;

    if (settingUp) {
      if (entered.trim().length < kMinPinLength) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l.t('admin.pin.short'))),
        );
        return;
      }
      widget.settings.setPin(entered.trim());
    } else if (entered.trim() != widget.settings.pin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l.t('admin.pin.wrong'))),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          settings: widget.settings,
          locale: widget.locale,
        ),
      ),
    );
    // Nach einer Aenderung kann die bisherige Auswahl ausgeblendet sein,
    // und die Personalliste eine andere.
    _api.staffCsv = widget.settings.staffCsv;
    if (mounted) _reset();
  }

  Future<String?> _askPin({bool settingUp = false}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          _l.t(settingUp ? 'admin.pin.set' : 'admin.pin.title'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 340,
          child: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, letterSpacing: 8),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              helperText: settingUp ? _l.t('admin.pin.short') : null,
            ),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_l.t('close'), style: const TextStyle(fontSize: 18)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(_l.t('admin.title'),
                style: const TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  // --- Barcode ---------------------------------------------------------

  /// Oeffnet die Kamera und uebernimmt die erste erkannte Sendungsnummer.
  /// Abbrechen laesst alles beim Alten -- der Scan ist freiwillig.
  Future<void> _scanBarcode() async {
    _touch();
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => ScanScreen(locale: widget.locale),
      ),
    );
    if (!mounted || code == null || code.isEmpty) return;
    setState(() => _tracking = code);
    _touch();
  }

  // --- Telefon ---------------------------------------------------------

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    final ok = await launchUrl(uri).catchError((_) => false);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_l.t('phone.failed')} $number')),
      );
    }
  }

  void _showPhones() {
    _touch();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          _l.t('phone.title'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in kPhoneContacts)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.accent,
                    radius: 26,
                    child: Icon(Icons.call, color: Colors.white, size: 26),
                  ),
                  title: Text(
                    switch (widget.locale.value) {
                      AppLang.fr => c.labelFr,
                      AppLang.de => c.labelDe,
                      AppLang.en => c.labelEn,
                    },
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text(
                    c.number,
                    style: const TextStyle(fontSize: 20, letterSpacing: 0.5),
                  ),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _call(c.number);
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_l.t('close'), style: const TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  // --- Aufbau ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _touch(),
      child: Scaffold(
        appBar: _appBar(),
        body: SafeArea(
          child: _success ? _successView() : _formView(),
        ),
        bottomNavigationBar: _success ? null : _sendBar(),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    // Mit Beschriftung brauchen die beiden Knoepfe so viel Platz, dass auf
    // schmalen Bildschirmen das Logo darunter verschwindet.
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return AppBar(
      backgroundColor: AppColors.ink,
      foregroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 82,
      titleSpacing: 16,
      title: Row(
        children: [
          // Weisse Flaeche, weil der Zusatz "natürlich frischer" im Logo
          // dunkel ist und auf dem dunklen Balken sonst verschwindet.
          // Verwaltung liegt hinter einem langen Druck aufs Logo: am
          // Empfang faellt niemand versehentlich hinein.
          GestureDetector(
            onLongPress: _openSettings,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/frigemo-logo.png',
                height: 34,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _l.t('app.title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _l.t('app.subtitle').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 2.4,
                    color: Color(0xFF9FB3C1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (wide)
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            ),
            onPressed: _toggleLanguage,
            icon: const Icon(Icons.language, size: 24),
            label: Text(
              _l.t('lang.switch'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          )
        else
          IconButton(
            tooltip: _l.t('lang.switch'),
            color: Colors.white,
            iconSize: 26,
            onPressed: _toggleLanguage,
            icon: const Icon(Icons.language),
          ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: wide
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _showPhones,
                  icon: const Icon(Icons.phone, size: 22),
                  label: Text(
                    _l.t('phone.button'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                )
              : IconButton(
                  tooltip: _l.t('phone.button'),
                  color: Colors.white,
                  iconSize: 26,
                  onPressed: _showPhones,
                  icon: const Icon(Icons.phone),
                ),
        ),
      ],
    );
  }

  Widget _formView() {
    // Auf dem Tablet quer stehen Transporteur und Empfaenger links, die
    // Angaben rechts: alle drei Schritte ohne Scrollen im Blick. Schmalere
    // oder hochkant montierte Bildschirme behalten die eine Bahn.
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final chooser = <Widget>[
      _stepLabel('1', _l.t('step.carrier')),
      const SizedBox(height: 14),
      _carrierGrid(),
      if (_carrier?.id == 'other') ...[
        const SizedBox(height: 14),
        TextField(
          controller: _otherCarrierCtrl,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 19),
          decoration: InputDecoration(
            labelText: _l.t('carrier.other.name'),
            labelStyle: const TextStyle(fontSize: 17),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          ),
        ),
      ],
      const SizedBox(height: 32),
      _stepLabel('2', _l.t('step.recipient')),
      const SizedBox(height: 14),
      _recipientField(),
    ];

    final details = <Widget>[
      _stepLabel('3', _l.t('step.details')),
      const SizedBox(height: 14),
      _detailsCard(),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: chooser,
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: details,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...chooser,
                const SizedBox(height: 32),
                ...details,
              ],
            ),
    );
  }

  Widget _stepLabel(String number, String text) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.ink,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 15,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
            color: AppColors.inkSoft,
          ),
        ),
      ],
    );
  }

  Widget _carrierGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 900 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 78,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: kCarriers.length,
          itemBuilder: (context, index) {
            final c = kCarriers[index];
            final selected = _carrier?.id == c.id;
            final label = c.id == 'other' ? _l.t('carrier.other') : c.label;

            return Material(
              color: Color(c.background),
              borderRadius: BorderRadius.circular(12),
              elevation: selected ? 6 : 1,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => _carrier = c);
                  _touch();
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.ink : Colors.transparent,
                      width: 4,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(c.foreground),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _recipientField() {
    final free = _freeName;
    if (free != null) return _freeNameCard(free);
    if (_unknownRecipient) return _unknownRecipientCard();

    if (_recipient != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent, width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.person, color: AppColors.accent, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _recipient!.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_recipient!.department.isNotEmpty)
                    Text(
                      _recipient!.department,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.inkSoft,
                      ),
                    ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _clearRecipient,
              icon: const Icon(Icons.close, size: 22),
              label: Text(
                _l.t('search.change'),
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: _l.t('search.hint'),
              prefixIcon: const Icon(Icons.search, size: 28),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            ),
            style: const TextStyle(fontSize: 21),
          ),
        ),
        const SizedBox(height: 10),
        _searchFeedback(),
        const SizedBox(height: 4),
        if (widget.settings.hasSharedMailbox)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              _searchFocus.unfocus();
              setState(() {
                _unknownRecipient = true;
                _recipient = null;
                _results = const [];
                _searching = false;
                _searchFailed = false;
                _searchCtrl.removeListener(_onSearchChanged);
                _searchCtrl.clear();
                _searchCtrl.addListener(_onSearchChanged);
              });
              _touch();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
            icon: const Icon(Icons.help_outline, size: 22),
            label: Text(
              _l.t('recipient.unknown'),
              style: const TextStyle(fontSize: 17),
            ),
          ),
        ),
      ],
    );
  }

  void _useFreeName(String name) {
    _searchFocus.unfocus();
    setState(() {
      _freeName = name.trim();
      _recipient = null;
      _unknownRecipient = false;
      _results = const [];
      _searching = false;
      _searchFailed = false;
    });
    _touch();
  }

  /// Ein Name vom Etikett, den die Liste nicht kennt.
  Widget _freeNameCard(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: AppColors.accent, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _l.t('recipient.free.hint'),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _freeName = null;
                _searchCtrl.removeListener(_onSearchChanged);
                _searchCtrl.clear();
                _searchCtrl.addListener(_onSearchChanged);
              });
              _searchFocus.requestFocus();
              _touch();
            },
            child: Text(
              _l.t('search.change'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  /// Auf mancher Sendung steht kein Name. Dann geht die Meldung nur an das
  /// gemeinsame Postfach – der Zustand muss aber sichtbar sein, damit ihn
  /// niemand aus Versehen stehen laesst.
  Widget _unknownRecipientCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.alert, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.help_outline, color: AppColors.alert, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _l.t('recipient.unknown'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _l.t('recipient.unknown.hint'),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _unknownRecipient = false);
              _searchFocus.requestFocus();
              _touch();
            },
            child: Text(
              _l.t('search.change'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchFeedback() {
    final query = _searchCtrl.text.trim();

    if (_searchFailed) {
      return _hintRow(
        Icons.cloud_off,
        _l.t('error.list'),
        AppColors.danger,
        action: TextButton(
          onPressed: () => _runSearch(query),
          child: Text(_l.t('retry'), style: const TextStyle(fontSize: 17)),
        ),
      );
    }

    if (query.length < AppConfig.minSearchChars) {
      // "Ihr Zeichen" verbindet kein Kurier von sich aus mit dem Empfaenger.
      // Der Hinweis erspart das Suchen -- und bringt Meldungen mit Namen
      // statt "unbekannt".
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hintRow(Icons.info_outline, _l.t('search.min'), AppColors.inkSoft),
          const SizedBox(height: 6),
          _hintRow(
            Icons.description_outlined,
            _l.t('search.where'),
            AppColors.inkSoft,
          ),
        ],
      );
    }

    if (_searching) return const SizedBox(height: 8);

    if (_results.isEmpty) {
      // Der Name auf dem Paket ist das Nuetzlichste an der Meldung. Steht
      // die Person nicht in der Liste, darf er trotzdem mitgehen.
      return _hintRow(
        Icons.person_off_outlined,
        _l.t('search.none'),
        AppColors.inkSoft,
        action: widget.settings.hasSharedMailbox
            ? TextButton(
                onPressed: () => _useFreeName(query),
                child: Text(
                  _l.t('recipient.free', args: {'name': query}),
                  style: const TextStyle(fontSize: 17),
                ),
              )
            : null,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _results.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.line),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: Text(
                _results[i].name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              subtitle: _results[i].department.isEmpty
                  ? null
                  : Text(
                      _results[i].department,
                      style: const TextStyle(fontSize: 16),
                    ),
              trailing: const Icon(Icons.chevron_right, size: 28),
              onTap: () => _selectRecipient(_results[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hintRow(IconData icon, String text, Color color, {Widget? action}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 16, color: color)),
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _detailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _l.t('quantity'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _stepper(),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            _l.t('kind.label'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in widget.settings.visibleKinds)
                _choiceChip(
                  label: widget.settings.labelOf(entry, _l, 'kind'),
                  selected: _kindEntry.id == entry.id,
                  color: entry.urgent ? AppColors.alert : AppColors.ink,
                  onTap: () {
                    setState(() {
                      _kind = entry.id;
                      // Kuehlware gehoert in den Kuehlraum -- sofern es ihn
                      // in den Einstellungen noch gibt.
                      if (entry.urgent && widget.settings.askLocation) {
                        final cold = widget.settings.visibleLocations
                            .where((e) => e.id == 'coldroom');
                        if (cold.isNotEmpty) _location = cold.first.id;
                      }
                    });
                    _touch();
                  },
                ),
            ],
          ),
          if (_kindEntry.urgent) ...[
            const SizedBox(height: 12),
            _hintRow(Icons.ac_unit, _l.t('chilled.warning'), AppColors.alert),
          ],
          // Der Fahrer weiss nicht, wohin die Sendung im Werk gehoert.
          // Standardmaessig fragt das Terminal ihn deshalb nicht danach.
          if (widget.settings.askLocation) ...[
            const SizedBox(height: 22),
            Text(
              _l.t('location.label'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final entry in widget.settings.visibleLocations)
                  _choiceChip(
                    label: widget.settings.labelOf(entry, _l, 'location'),
                    selected: _locationEntry.id == entry.id,
                    color: AppColors.ink,
                    onTap: () {
                      setState(() => _location = entry.id);
                      _touch();
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          _trackingField(),
          const SizedBox(height: 22),
          TextField(
            controller: _noteCtrl,
            maxLength: 120,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              labelText: _l.t('note.label'),
              labelStyle: const TextStyle(fontSize: 17),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            onChanged: (_) => _touch(),
          ),
        ],
      ),
    );
  }

  /// Ohne Nummer ein Scan-Knopf, mit Nummer die Anzeige samt Entfernen.
  /// Nochmals scannen ersetzt die Nummer -- pro Meldung gilt eine Sendung.
  Widget _trackingField() {
    if (_tracking.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.ink,
            side: const BorderSide(color: AppColors.line, width: 2),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _scanBarcode,
          icon: const Icon(Icons.qr_code_scanner, size: 24),
          label: Text(
            _l.t('scan.button'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_2, size: 26, color: AppColors.inkSoft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _l.t('tracking.label'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _tracking,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _l.t('admin.delete'),
            onPressed: () {
              setState(() => _tracking = '');
              _touch();
            },
            icon: const Icon(Icons.close, size: 24, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _stepper() {
    return Row(
      children: [
        _roundButton(Icons.remove, _quantity > 1, () {
          setState(() => _quantity--);
          _touch();
        }),
        SizedBox(
          width: 72,
          child: Text(
            '$_quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
        ),
        _roundButton(Icons.add, _quantity < AppConfig.maxQuantity, () {
          setState(() => _quantity++);
          _touch();
        }),
      ],
    );
  }

  Widget _roundButton(IconData icon, bool enabled, VoidCallback onTap) {
    return Material(
      color: enabled ? AppColors.surface : AppColors.surface.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            icon,
            size: 28,
            color: enabled ? AppColors.ink : AppColors.line,
          ),
        ),
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? color : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? color : AppColors.line, width: 2),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sendBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              disabledBackgroundColor: AppColors.line,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _ready ? _submit : null,
            icon: _submitting
                ? const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 28),
            label: Text(
              _submitting ? _l.t('sending') : _l.t('send'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _successView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 44),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.accent, size: 104),
            const SizedBox(height: 24),
            Text(
              _l.t('success.title'),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              _recipient != null
                  ? _l.t('success.body', args: {'name': _recipient!.name})
                  : _freeName != null
                      ? _l.t('success.body', args: {'name': _freeName!})
                      : _l.t('success.body.unknown'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 32),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _reset,
              child: Text(
                _l.t('success.next'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
