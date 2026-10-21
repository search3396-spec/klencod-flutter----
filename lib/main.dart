import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

void main() => runApp(const SamIdeApp());

const bg = Color(0xFF0B1020);
const panel = Color(0xFF121A2B);
const panel2 = Color(0xFF192338);
const accent = Color(0xFF62E6B5);
const muted = Color(0xFF9AA8BD);

class SamIdeApp extends StatelessWidget {
  const SamIdeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SAM IDE',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(primary: accent, surface: panel),
      useMaterial3: true,
      fontFamily: 'monospace',
    ),
    home: const IdeHome(),
  );
}

class BotProject {
  BotProject(this.name, this.path, this.code);
  String name;
  String path;
  String code;
}

class IdeHome extends StatefulWidget {
  const IdeHome({super.key});
  @override
  State<IdeHome> createState() => _IdeHomeState();
}

class _IdeHomeState extends State<IdeHome> {
  final List<BotProject> projects = [];
  BotProject? selected;
  final TextEditingController editor = TextEditingController();
  final List<String> logs = [
    'SAM IDE ready.',
    'Choose a project or create a new .py file.',
    'Note: Python execution is not connected in this starter build.',
  ];
  bool running = false;
  int tab = 0;

  @override
  void initState() {
    super.initState();
    _loadStarter();
  }

  Future<Directory> _projectDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/sam_projects');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _loadStarter() async {
    final dir = await _projectDir();
    final file = File('${dir.path}/SAM.py');
    if (!await file.exists()) {
      await file.writeAsString('''# SAM Telegram bot
# Add your bot token privately. Do not share this file.
TOKEN = "PASTE_YOUR_BOT_TOKEN_HERE"

async def start(update, context):
    await update.message.reply_text("مرحباً! 🤖")

# Starter template only: execution is not connected yet.
''');
    }
    await _refreshProjects();
  }

  Future<void> _refreshProjects() async {
    final dir = await _projectDir();
    final found = <BotProject>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.py')) {
        found.add(BotProject(entity.uri.pathSegments.last, entity.path, await entity.readAsString()));
      }
    }
    found.sort((a,b) => a.name.compareTo(b.name));
    setState(() {
      projects
        ..clear()
        ..addAll(found);
      if (selected != null) {
        selected = projects.where((p) => p.path == selected!.path).firstOrNull;
      }
      if (selected == null && projects.isNotEmpty) selected = projects.first;
      editor.text = selected?.code ?? '';
    });
  }

  Future<void> _openProject(BotProject p) async {
    setState(() {
      selected = p;
      editor.text = p.code;
      tab = 0;
    });
  }

  Future<void> _save() async {
    if (selected == null) return;
    await File(selected!.path).writeAsString(editor.text);
    selected!.code = editor.text;
    setState(() => logs.insert(0, 'Saved ${selected!.name}'));
    _notify('Saved ${selected!.name}');
  }

  Future<void> _newProject() async {
    final controller = TextEditingController(text: 'NewBot.py');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: panel,
        title: const Text('New Python file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'BotName.py'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    var safe = name.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    if (!safe.toLowerCase().endsWith('.py')) safe = '$safe.py';
    final dir = await _projectDir();
    final file = File('${dir.path}/$safe');
    if (await file.exists()) {
      _notify('A file with that name already exists');
      return;
    }
    await file.writeAsString('# $safe\nTOKEN = "PASTE_YOUR_BOT_TOKEN_HERE"\n\nasync def start(update, context):\n    await update.message.reply_text("Hello!")\n');
    await _refreshProjects();
    final p = projects.where((x) => x.path == file.path).firstOrNull;
    if (p != null) await _openProject(p);
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['py'], withData: false);
    if (result == null || result.files.single.path == null) return;
    final source = File(result.files.single.path!);
    final dir = await _projectDir();
    final target = File('${dir.path}/${result.files.single.name}');
    await target.writeAsString(await source.readAsString());
    await _refreshProjects();
    final p = projects.where((x) => x.path == target.path).firstOrNull;
    if (p != null) await _openProject(p);
  }

  void _runNotice() {
    setState(() {
      running = !running;
      logs.insert(0, running
        ? 'Preview mode: Python runtime is not configured.'
        : 'Stopped preview.');
      tab = 1;
    });
    _notify(running
      ? 'This starter build cannot execute Python yet.'
      : 'Preview stopped');
  }

  void _notify(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  @override
  void dispose() {
    editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _topBar(),
          _toolbar(),
          Expanded(
            child: Row(children: [
              SizedBox(width: 142, child: _sidebar()),
              const VerticalDivider(width: 1, color: Color(0xFF253047)),
              Expanded(child: _workspace()),
            ]),
          ),
          _bottomStatus(),
        ]),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _newProject,
        backgroundColor: accent,
        foregroundColor: bg,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _topBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: const BoxDecoration(
      color: panel,
      border: Border(bottom: BorderSide(color: Color(0xFF253047)))),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: accent.withOpacity(.13), borderRadius: BorderRadius.circular(11)),
        child: const Icon(Icons.terminal, color: accent)),
      const SizedBox(width: 10),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SAM IDE', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        Text('PYTHON BOT WORKSPACE', style: TextStyle(fontSize: 9, color: muted, letterSpacing: 1.1)),
      ])),
      IconButton(tooltip: 'Import .py file', onPressed: _importFile, icon: const Icon(Icons.file_open)),
    ]),
  );

  Widget _toolbar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    color: bg,
    child: Row(children: [
      _toolButton(Icons.save_outlined, 'Save', _save),
      const SizedBox(width: 7),
      FilledButton.icon(
        onPressed: _runNotice,
        style: FilledButton.styleFrom(
          backgroundColor: running ? const Color(0xFFFF6B78) : accent,
          foregroundColor: bg,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10)),
        icon: Icon(running ? Icons.stop : Icons.play_arrow, size: 18),
        label: Text(running ? 'Stop' : 'Run')),
      const SizedBox(width: 7),
      _toolButton(Icons.refresh, 'Reload', _refreshProjects),
    ]),
  );

  Widget _toolButton(IconData icon, String label, VoidCallback action) => OutlinedButton.icon(
    onPressed: action,
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFD8E1EF),
      side: const BorderSide(color: Color(0xFF2A3851)),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10)),
    icon: Icon(icon, size: 16), label: Text(label, style: const TextStyle(fontSize: 12)));

  Widget _sidebar() => Container(
    color: panel,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(12, 14, 8, 10),
        child: Text('PROJECT FILES', style: TextStyle(fontSize: 10, color: muted, letterSpacing: 1))),
      if (projects.isEmpty)
        const Padding(padding: EdgeInsets.all(12), child: Text('No .py files', style: TextStyle(color: muted, fontSize: 12)))
      else
        ...projects.map((p) => InkWell(
          onTap: () => _openProject(p),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            color: selected?.path == p.path ? panel2 : Colors.transparent,
            child: Row(children: [
              const Icon(Icons.code, size: 16, color: accent),
              const SizedBox(width: 7),
              Expanded(child: Text(p.name, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: selected?.path == p.path ? Colors.white : muted))),
            ]),
          ),
        )),
      const Spacer(),
      Padding(padding: const EdgeInsets.all(8), child: TextButton.icon(
        onPressed: _newProject, icon: const Icon(Icons.add, size: 16), label: const Text('New file', style: TextStyle(fontSize: 11)))),
    ]),
  );

  Widget _workspace() => Column(children: [
    Container(
      color: panel,
      child: Row(children: [
        _tabButton('Editor', 0, Icons.code),
        _tabButton('Terminal', 1, Icons.terminal),
        _tabButton('Bot info', 2, Icons.smart_toy_outlined),
      ]),
    ),
    Expanded(child: IndexedStack(index: tab, children: [
      _editorPane(),
      _terminalPane(),
      _infoPane(),
    ])),
  ]);

  Widget _tabButton(String title, int index, IconData icon) => InkWell(
    onTap: () => setState(() => tab = index),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(
        color: tab == index ? accent : Colors.transparent, width: 2))),
      child: Row(children: [
        Icon(icon, size: 14, color: tab == index ? accent : muted),
        const SizedBox(width: 5),
        Text(title, style: TextStyle(fontSize: 11, color: tab == index ? Colors.white : muted)),
      ]),
    ),
  );

  Widget _editorPane() => Column(children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      color: const Color(0xFF0E1525),
      child: Row(children: [
        const Icon(Icons.circle, size: 8, color: Color(0xFFFFC857)),
        const SizedBox(width: 8),
        Expanded(child: Text(selected?.name ?? 'No file selected',
          style: const TextStyle(fontSize: 12, color: muted))),
        const Text('Python', style: TextStyle(fontSize: 10, color: accent)),
      ]),
    ),
    Expanded(child: TextField(
      controller: editor,
      expands: true,
      maxLines: null,
      minLines: null,
      keyboardType: TextInputType.multiline,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(fontSize: 13, height: 1.55, color: Color(0xFFDCE7F7)),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.all(14),
        border: InputBorder.none,
        hintText: '# Write Python code here...',
        hintStyle: TextStyle(color: Color(0xFF65738A))),
    )),
  ]);

  Widget _terminalPane() => Container(
    color: const Color(0xFF070B14),
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('TERMINAL  •  OUTPUT', style: TextStyle(color: accent, fontSize: 11, letterSpacing: 1)),
      const SizedBox(height: 12),
      Expanded(child: ListView.builder(
        reverse: true,
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final line = logs[index];
          final isWarning = line.toLowerCase().contains('not configured') || line.toLowerCase().contains('cannot execute');
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('› $line', style: TextStyle(
              fontSize: 11, height: 1.4,
              color: isWarning ? const Color(0xFFFFC857) : const Color(0xFFB7C7D9))));
        })),
      const Text('Real Python execution is not yet enabled.', style: TextStyle(color: muted, fontSize: 10)),
    ]),
  );

  Widget _infoPane() => Padding(
    padding: const EdgeInsets.all(16),
    child: ListView(children: [
      const Icon(Icons.smart_toy_outlined, size: 42, color: accent),
      const SizedBox(height: 12),
      Text(selected?.name ?? 'No project selected', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      _infoRow('File type', '.py'),
      _infoRow('Saved locally', 'Yes'),
      _infoRow('Python runtime', 'Not connected'),
      _infoRow('Telegram status', 'Not checked'),
      const SizedBox(height: 14),
      const Text('This is the starter interface. A bundled Android Python runtime and Telegram library must be added before the Run button can launch real bots.', style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
      const SizedBox(height: 12),
      const Text('Security: avoid sharing bot tokens. If a token is exposed, regenerate it using BotFather.', style: TextStyle(color: Color(0xFFFFC857), fontSize: 12, height: 1.5)),
    ]),
  );

  Widget _infoRow(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF253047)))),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: muted, fontSize: 12))),
      Text(value, style: const TextStyle(fontSize: 12)),
    ]),
  );

  Widget _bottomStatus() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    color: const Color(0xFF101827),
    child: Row(children: [
      const Icon(Icons.circle, size: 7, color: accent),
      const SizedBox(width: 6),
      Text('${projects.length} project(s)', style: const TextStyle(fontSize: 10, color: muted)),
      const Spacer(),
      const Text('Android • Starter build', style: TextStyle(fontSize: 10, color: muted)),
    ]),
  );
}
