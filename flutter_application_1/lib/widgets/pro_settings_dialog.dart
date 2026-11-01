import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/language_service.dart';
import '../services/socket_service.dart';
import '../theme.dart';

/// EduTrace Pro settings. The engine stores everything; secrets never come back to the panel.
class ProSettingsDialog extends StatelessWidget {
  const ProSettingsDialog({super.key});

  /// Displays the Pro settings dialog.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ProSettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: DefaultTabController(
          length: 3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 8, 0),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Text(
                      lang.isEnglish ? 'Pro Settings' : 'Pro Ayarları',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              TabBar(
                isScrollable: true,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.accent,
                tabs: [
                  Tab(text: lang.isEnglish ? 'Notifications' : 'Bildirimler'),
                  Tab(text: lang.isEnglish ? 'Auto Response' : 'Otomatik Müdahale'),
                  Tab(text: lang.isEnglish ? 'Rules' : 'Kurallar'),
                ],
              ),
              const Flexible(
                child: TabBarView(
                  children: [
                    _NotificationsTab(),
                    _AutoResponseTab(),
                    _RulesTab(),
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

class _NotificationsTab extends StatefulWidget {
  const _NotificationsTab();

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  // Plain settings are prefilled; secret fields stay empty and empty means "keep".
  static const _plainKeys = [
    'telegram_chat_id',
    'smtp_sunucu',
    'smtp_port',
    'smtp_kullanici',
    'eposta_alici',
  ];
  static const _secretKeys = ['telegram_token', 'smtp_sifre'];

  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _clearSecrets = {};

  @override
  void initState() {
    super.initState();
    final current = context.read<SocketService>().notificationSettings;
    for (final key in _plainKeys) {
      _controllers[key] = TextEditingController(text: current[key]?.toString() ?? '');
    }
    for (final key in _secretKeys) {
      _controllers[key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final settings = <String, dynamic>{
      for (final e in _controllers.entries) e.key: e.value.text.trim(),
      for (final key in _clearSecrets) '${key}_sil': true,
    };
    context.read<SocketService>().saveNotificationSettings(settings);
    for (final key in _secretKeys) {
      _controllers[key]!.clear();
    }
    setState(_clearSecrets.clear);
  }

  Widget _field(String key, String label, {bool secret = false, String? hint}) {
    final settings = context.watch<SocketService>().notificationSettings;
    final isSet = secret && settings['${key}_tanimli'] == true && !_clearSecrets.contains(key);
    final lang = context.read<LanguageService>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _controllers[key],
        obscureText: secret,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          hintText: isSet
              ? (lang.isEnglish ? 'Saved — leave empty to keep' : 'Kayıtlı — değiştirmek istemiyorsan boş bırak')
              : hint,
          suffixIcon: isSet
              ? IconButton(
                  tooltip: lang.isEnglish ? 'Remove' : 'Sil',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => setState(() => _clearSecrets.add(key)),
                )
              : null,
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final en = lang.isEnglish;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            en
                ? 'Get an alert on your phone or inbox when EduTrace blocks an attack. '
                    'At most one message per IP every 10 minutes and 20 per hour.'
                : 'EduTrace bir saldırıyı engellediğinde telefonuna veya e-postana haber gelir. '
                    'Aynı IP için 10 dakikada en fazla bir, saatte en fazla 20 mesaj gönderilir.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          _section('Telegram'),
          _field('telegram_token', 'Bot token', secret: true, hint: '123456:ABC... (@BotFather)'),
          _field('telegram_chat_id', 'Chat ID', hint: en ? 'e.g. 123456789' : 'örn. 123456789'),
          _section(en ? 'E-mail (SMTP)' : 'E-posta (SMTP)'),
          _field('smtp_sunucu', en ? 'SMTP server' : 'SMTP sunucusu', hint: 'smtp.gmail.com'),
          _field('smtp_port', 'Port', hint: '587'),
          _field('smtp_kullanici', en ? 'Username' : 'Kullanıcı adı'),
          _field('smtp_sifre', en ? 'Password / app password' : 'Şifre / uygulama şifresi', secret: true),
          _field('eposta_alici', en ? 'Send alerts to' : 'Alarmların gideceği adres'),
          const SizedBox(height: 6),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => context.read<SocketService>().sendTestNotification(),
                icon: const Icon(Icons.send, size: 16),
                label: Text(en ? 'Send test' : 'Test gönder'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _save,
                child: Text(en ? 'Save' : 'Kaydet'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AutoResponseTab extends StatefulWidget {
  const _AutoResponseTab();

  @override
  State<_AutoResponseTab> createState() => _AutoResponseTabState();
}

class _AutoResponseTabState extends State<_AutoResponseTab> {
  late bool _firewall;
  late bool _terminate;
  late final TextEditingController _whitelist;

  @override
  void initState() {
    super.initState();
    final current = context.read<SocketService>().autoResponse;
    _firewall = current['oto_firewall'] == true;
    _terminate = current['oto_sonlandir'] == true;
    final list = current['beyaz_liste'];
    _whitelist = TextEditingController(text: list is List ? list.join('\n') : '');
  }

  @override
  void dispose() {
    _whitelist.dispose();
    super.dispose();
  }

  void _save() {
    final entries = _whitelist.text
        .split(RegExp(r'[\s,;]+'))
        .where((e) => e.isNotEmpty)
        .toList();
    context.read<SocketService>().saveAutoResponse(
          firewall: _firewall,
          terminate: _terminate,
          whitelist: entries,
        );
  }

  @override
  Widget build(BuildContext context) {
    final en = context.watch<LanguageService>().isEnglish;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            en
                ? 'Both are off by default. A false positive can cut a legitimate connection or close a '
                    'program you use, so turn them on only if you accept that. Blocks can be undone '
                    'from Alert History > Blocked IPs.'
                : 'İkisi de varsayılan olarak kapalı. Yanlış bir alarm meşru bir bağlantıyı kesebilir veya '
                    'kullandığın bir programı kapatabilir; bunu kabul ediyorsan aç. Engeller Alarm Geçmişi > '
                    "Engellenen IP'ler bölümünden geri alınabilir.",
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _firewall,
            onChanged: (v) => setState(() => _firewall = v),
            title: Text(
              en ? 'Block attackers in Windows Firewall' : "Saldırgan IP'yi Windows Güvenlik Duvarı'nda engelle",
            ),
            subtitle: Text(
              en ? 'Private and local addresses are never blocked.' : 'Yerel ve özel ağ adresleri asla engellenmez.',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          SwitchListTile(
            value: _terminate,
            onChanged: (v) => setState(() => _terminate = v),
            title: Text(en ? 'Terminate the process behind an attack' : 'Saldırıya aracılık eden süreci sonlandır'),
            subtitle: Text(
              en ? 'Critical Windows processes are protected.' : 'Kritik Windows süreçleri korunur.',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            en ? 'Whitelist (IP or CIDR, one per line)' : 'Beyaz liste (IP veya CIDR, her satıra bir tane)',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _whitelist,
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(fontSize: 13, fontFamily: 'Consolas'),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              hintText: '203.0.113.10\n198.51.100.0/24',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _save, child: Text(en ? 'Save' : 'Kaydet')),
          ),
        ],
      ),
    );
  }
}

/// One editable custom port rule.
class _RuleRow {
  _RuleRow({String name = '', String port = '', this.proto = 'TCP', String threshold = '10', this.severity = 'ORTA'})
      : name = TextEditingController(text: name),
        port = TextEditingController(text: port),
        threshold = TextEditingController(text: threshold);

  final TextEditingController name;
  final TextEditingController port;
  final TextEditingController threshold;
  String proto;
  String severity;

  void dispose() {
    name.dispose();
    port.dispose();
    threshold.dispose();
  }
}

class _RulesTab extends StatefulWidget {
  const _RulesTab();

  @override
  State<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<_RulesTab> {
  static const _labels = {
    'icmp': ('Ping flood (ICMP, more than)', 'Ping flood (ICMP, şundan fazla)'),
    'udp': ('UDP flood (more than)', 'UDP flood (şundan fazla)'),
    'gizli_tarama': ('Stealth scan probes (NULL/FIN/XMAS)', 'Gizli tarama paketleri (NULL/FIN/XMAS)'),
    'kritik_servis': ('Packets to one critical port (RDP, SMB, SSH…)', 'Tek kritik porta paket (RDP, SMB, SSH…)'),
    'syn': ('SYN flood (bare SYN packets)', 'SYN flood (yalın SYN paketi)'),
    'yavas_tarama_port': ('Slow scan: distinct ports', 'Yavaş tarama: farklı port'),
    'yavas_tarama_paket': ('Slow scan: minimum packets', 'Yavaş tarama: en az paket'),
  };

  final Map<String, TextEditingController> _thresholds = {};
  final List<_RuleRow> _rows = [];
  Map<String, dynamic> _defaults = {};

  @override
  void initState() {
    super.initState();
    final rules = context.read<SocketService>().rules;
    final current = rules['esikler'] is Map ? Map<String, dynamic>.from(rules['esikler'] as Map) : {};
    _defaults = rules['varsayilan'] is Map ? Map<String, dynamic>.from(rules['varsayilan'] as Map) : {};
    for (final key in _labels.keys) {
      _thresholds[key] = TextEditingController(text: '${current[key] ?? _defaults[key] ?? ''}');
    }
    final list = rules['kurallar'];
    if (list is List) {
      for (final r in list.whereType<Map>()) {
        _rows.add(_RuleRow(
          name: '${r['ad'] ?? ''}',
          port: '${r['port'] ?? ''}',
          proto: '${r['proto'] ?? 'TCP'}',
          threshold: '${r['esik'] ?? ''}',
          severity: '${r['siddet'] ?? 'ORTA'}',
        ));
      }
    }
  }

  @override
  void dispose() {
    for (final c in _thresholds.values) {
      c.dispose();
    }
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _resetDefaults() {
    setState(() {
      for (final e in _thresholds.entries) {
        e.value.text = '${_defaults[e.key] ?? e.value.text}';
      }
    });
  }

  void _save() {
    final thresholds = <String, int>{};
    for (final e in _thresholds.entries) {
      final v = int.tryParse(e.value.text.trim());
      if (v != null) {
        thresholds[e.key] = v;
      }
    }
    final rules = [
      for (final r in _rows)
        {
          'ad': r.name.text.trim(),
          'port': int.tryParse(r.port.text.trim()) ?? 0,
          'proto': r.proto,
          'esik': int.tryParse(r.threshold.text.trim()) ?? 0,
          'siddet': r.severity,
        },
    ];
    context.read<SocketService>().saveRules(thresholds, rules);
  }

  Widget _numberField(TextEditingController c, {String? label, double width = 90}) => SizedBox(
        width: width,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        ),
      );

  Widget _dropdown(String value, List<String> items, ValueChanged<String> onChanged) => DropdownButton<String>(
        value: items.contains(value) ? value : items.first,
        isDense: true,
        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        dropdownColor: AppColors.surfaceAlt,
        items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i))],
        onChanged: (v) => setState(() => onChanged(v ?? items.first)),
      );

  @override
  Widget build(BuildContext context) {
    final en = context.watch<LanguageService>().isEnglish;
    const heading = TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(en ? 'Thresholds (per 60 s, per IP)' : 'Eşikler (IP başına, 60 sn içinde)', style: heading),
              const Spacer(),
              TextButton(onPressed: _resetDefaults, child: Text(en ? 'Defaults' : 'Varsayılanlar')),
            ],
          ),
          Text(
            en
                ? 'Lower values catch attacks earlier but raise false alarms.'
                : 'Düşük değer saldırıyı erken yakalar ama yanlış alarmı artırır.',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          for (final e in _labels.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(en ? e.value.$1 : e.value.$2, style: const TextStyle(fontSize: 12))),
                  _numberField(_thresholds[e.key]!),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(en ? 'Custom port rules' : 'Özel port kuralları', style: heading),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _rows.add(_RuleRow())),
                icon: const Icon(Icons.add, size: 16),
                label: Text(en ? 'Add rule' : 'Kural ekle'),
              ),
            ],
          ),
          Text(
            en
                ? 'Alert when one IP sends at least N packets to a port within 60 s. Example: MongoDB, TCP 27017, 10.'
                : 'Bir IP 60 sn içinde bir porta en az N paket gönderirse alarm ver. Örnek: MongoDB, TCP 27017, 10.',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          for (final r in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: r.name,
                      maxLength: 60,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: en ? 'Name' : 'Ad',
                        isDense: true,
                        counterText: '',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _numberField(r.port, label: 'Port', width: 70),
                  const SizedBox(width: 6),
                  _dropdown(r.proto, const ['TCP', 'UDP', 'HEPSI'], (v) => r.proto = v),
                  const SizedBox(width: 6),
                  _numberField(r.threshold, label: en ? 'Min' : 'Eşik', width: 64),
                  const SizedBox(width: 6),
                  _dropdown(r.severity, const ['DUSUK', 'ORTA', 'YUKSEK', 'KRITIK'], (v) => r.severity = v),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => setState(() => _rows.remove(r..dispose())),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _save, child: Text(en ? 'Save' : 'Kaydet')),
          ),
        ],
      ),
    );
  }
}
