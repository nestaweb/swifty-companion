import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'search/search_view.dart';
import 'profile/profile_view.dart';

class MyApp extends StatelessWidget {
	const MyApp({
		super.key,
	});


	@override
	Widget build(BuildContext context) {

		return ListenableBuilder(
			listenable: ValueNotifier<int>(0),
			builder: (BuildContext context, Widget? child) {
				return MaterialApp(
					restorationScopeId: 'app',

					localizationsDelegates: const [
						AppLocalizations.delegate,
						GlobalMaterialLocalizations.delegate,
						GlobalWidgetsLocalizations.delegate,
						GlobalCupertinoLocalizations.delegate,
					],
					supportedLocales: const [
						Locale('en', ''),
					],

					onGenerateTitle: (BuildContext context) =>
						AppLocalizations.of(context)!.appTitle,

					theme: ThemeData.dark(),
					
					onGenerateRoute: (RouteSettings routeSettings) {
						return MaterialPageRoute<void>(
							settings: routeSettings,
							builder: (BuildContext context) {
								switch (routeSettings.name) {
								case ProfilePage.routeName:
									return const ProfilePage();
								default:
									return const LoginPage();
								}
							},
						);
					},
				);
			},
		);
	}
}
