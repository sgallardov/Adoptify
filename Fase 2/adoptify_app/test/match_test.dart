import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/core/location_service.dart';

import 'fake_api.dart';
import 'map_test.dart' show openMap, tapAndSettle;

void main() {
  setUp(() => LocationService.instance = FakeLocation());
  tearDown(() => LocationService.instance = LocationService());

  testWidgets('el botón Haz Match! del mapa abre el match y se puede volver', (tester) async {
    await openMap(tester, FakeApi());

    await tapAndSettle(tester, find.text('Haz Match!'));
    expect(find.text('Muy pronto'), findsOneWidget);

    await tapAndSettle(tester, find.byTooltip('Back'));
    expect(find.text('Muy pronto'), findsNothing);
    expect(find.text('Haz Match!'), findsOneWidget);
  });
}
