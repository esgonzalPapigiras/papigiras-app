import 'package:flutter/material.dart';
import '../dto/coordinator_session.dart';
import '../dto/responseAttorney.dart';
import 'local_access.dart';
import 'session.dart';

class LocalAccessPanel extends StatefulWidget {
  const LocalAccessPanel({
    super.key,
    required this.role,
    required this.destination,
    this.client,
  });
  final String role;
  final Widget Function(String role, Map<String, dynamic> session) destination;
  @visibleForTesting
  final LocalAccessClient? client;
  @override
  State<LocalAccessPanel> createState() => _LocalAccessPanelState();
}

class _LocalAccessPanelState extends State<LocalAccessPanel> {
  late final LocalAccessClient _client;
  final _password = TextEditingController();
  final _search = TextEditingController();
  LocalProfilePage? _page;
  String _lastQuery = '';
  String? _error;
  bool _busy = false;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? LocalAccessClient();
  }

  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    _search.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_busy || _password.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _client.unlock(_password.text);
      if (!mounted) return;
      _unlocked = true;
      // Do not disclose a catalog before the user chooses what to search.
      _page = null;
      _lastQuery = '';
    } catch (_) {
      if (mounted)
        _error =
            'No se pudo abrir el acceso local. Revisa la clave del LAB y el servidor de tu Mac.';
    } finally {
      if (mounted) {
        _password.clear();
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _load({int offset = 0}) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final query = _search.text.trim();
    try {
      final page = await _client.profiles(
        widget.role,
        query: query,
        offset: query == _lastQuery ? offset : 0,
      );
      if (mounted)
        setState(() {
          _page = page;
          _lastQuery = query;
        });
    } catch (_) {
      if (mounted)
        _error =
            'No se pudo consultar el catálogo local. Vuelve a intentar o abre nuevamente el acceso.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(LocalProfile profile) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await _client.session(widget.role, profile.id);
      if (!mounted) return;
      if (widget.role == 'coordinator') {
        final login = CoordinatorLogin.fromJson(value);
        await LabSession.saveCoordinator(login);
      } else {
        final login = ResponseAttorney.fromJson(value);
        await LabSession.savePassenger(login, widget.role);
      }
      if (!mounted) return;
      _page = null;
      _search.clear();
      final next = widget.destination(widget.role, value);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => next),
        (_) => false,
      );
    } catch (_) {
      if (mounted)
        _error =
            'No se pudo abrir este perfil. Comprueba que tenga una gira asociada en la copia local.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = switch (widget.role) {
      'coordinator' => 'Coordinador',
      'attorney' => 'Apoderado',
      _ => 'Alumno',
    };
    final page = _page;
    return Scaffold(
      appBar: AppBar(title: Text('$role · Acceso LAB')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Copia local de datos recuperados · 03/11/2026',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _unlocked
                    ? 'Selecciona el perfil que quieres probar. Los cambios se guardan solamente en el LAB.'
                    : 'Usa la clave local del laboratorio. No ingreses contraseñas de la app oficial.',
              ),
              const SizedBox(height: 16),
              if (!_unlocked) ...[
                TextField(
                  controller: _password,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Clave local del LAB',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _unlock(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _unlock,
                  child: const Text('Abrir perfiles locales'),
                ),
              ] else ...[
                TextField(
                  controller: _search,
                  maxLength: 100,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Buscar perfil',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: 'Buscar',
                      onPressed: _busy ? null : _load,
                      icon: const Icon(Icons.search),
                    ),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ],
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_unlocked)
                Expanded(
                  child: page == null
                      ? const SizedBox.shrink()
                      : page.items.isEmpty
                      ? const Center(
                          child: Text('No hay perfiles para esta búsqueda.'),
                        )
                      : ListView.separated(
                          itemCount: page.items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final profile = page.items[i];
                            return ListTile(
                              title: Text(profile.label),
                              subtitle: profile.detail.isEmpty
                                  ? null
                                  : Text(profile.detail),
                              trailing: const Icon(Icons.chevron_right),
                              enabled: !_busy,
                              onTap: () => _select(profile),
                            );
                          },
                        ),
                ),
              if (_unlocked && page != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: !_busy && page.offset > 0
                          ? () => _load(
                              offset: (page.offset - 25).clamp(0, page.offset),
                            )
                          : null,
                      child: const Text('Anterior'),
                    ),
                    Text('Página ${page.offset ~/ 25 + 1}'),
                    TextButton(
                      onPressed: !_busy && page.hasMore
                          ? () => _load(offset: page.offset + 25)
                          : null,
                      child: const Text('Siguiente'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
