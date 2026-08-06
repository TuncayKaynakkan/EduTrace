import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/services/socket_service.dart';

void main() {
  testWidgets('Dashboard renders command center title', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SocketService(),
        child: const EduTraceApp(),
      ),
    );

    expect(find.text('EduTrace XDR - Komuta Merkezi'), findsOneWidget);
    expect(find.text('CANLI AG RADARI'), findsOneWidget);
    expect(find.text('AGA BAGLI SURECLER'), findsOneWidget);
  });
}
