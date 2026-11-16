import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/utils/passenger_roster_data.dart';

export 'package:papigiras_app/utils/passenger_roster_data.dart'
    show hasSpecialDiet;

List<PassengerList> specialDietPassengers(List<PassengerList> people) =>
    rosterPeople(people.where(hasSpecialDiet));

class SpecialDietPassengersScreen extends StatefulWidget {
  const SpecialDietPassengersScreen({super.key, required this.loadPassengers});

  /// The coordinator's existing protected roster, loaded only when opened.
  final Future<List<PassengerList>> Function() loadPassengers;

  @override
  State<SpecialDietPassengersScreen> createState() =>
      _SpecialDietPassengersScreenState();
}

class _SpecialDietPassengersScreenState
    extends State<SpecialDietPassengersScreen> {
  late Future<List<PassengerList>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PassengerList>> _load() async {
    final people = await widget.loadPassengers();
    if (people.any((person) => !person.hasDietInformation)) {
      // An old/incomplete response must not look like a zero-diet tour.
      throw StateError('Diet information is unavailable');
    }
    return specialDietPassengers(people);
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // FutureBuilder presents a safe error; never log passenger data.
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Builder(
      builder: (context) => Scaffold(
        backgroundColor: PiloFamilyTheme.paper,
        body: SafeArea(
          child: FutureBuilder<List<PassengerList>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return ListView(
                  children: [
                    _header(context),
                    const Center(
                      child: CircularProgressIndicator(
                        semanticsLabel:
                            'Cargando pasajeros con dietas especiales',
                      ),
                    ),
                  ],
                );
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _header(context, inset: false),
                    const Text(
                      'No pudimos cargar las dietas de los pasajeros.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _reload,
                      icon: const Icon(CupertinoIcons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                );
              }
              final people = snapshot.data!;
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView.separated(
                  key: const PageStorageKey('special-diet-passengers'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: people.isEmpty ? 3 : people.length + 2,
                  separatorBuilder: (_, index) => index < 2
                      ? const SizedBox(height: 4)
                      : const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _header(context, inset: false);
                    }
                    if (index == 1) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${people.length} ${people.length == 1 ? 'pasajero' : 'pasajeros'}',
                          key: const ValueKey('special-diet-list-count'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }
                    if (people.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Text(
                          'No hay dietas especiales registradas en esta gira.',
                        ),
                      );
                    }
                    final person = people[index - 2];
                    return _PassengerDietRow(
                      key: ValueKey('diet-passenger-${person.passengerId}'),
                      person: person,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _header(BuildContext context, {bool inset = true}) => PiloSectionBar(
    title: 'Dietas especiales',
    onBack: () => Navigator.of(context).maybePop(),
    compact: true,
    padding: EdgeInsets.fromLTRB(inset ? 20 : 0, 8, inset ? 20 : 0, 12),
  );
}

class _PassengerDietRow extends StatelessWidget {
  const _PassengerDietRow({super.key, required this.person});
  final PassengerList person;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rosterName(person),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            person.passengerIdentification.trim().isEmpty
                ? 'RUT no informado'
                : 'RUT: ${person.passengerIdentification}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.restaurant_rounded,
                  size: 18,
                  color: Color(0xFFA86600),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  person.passengerDiet!.trim(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
