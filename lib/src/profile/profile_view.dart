import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
	const ProfilePage({super.key});
	static const String routeName = '/profile';

	@override
	_ProfilePageState createState() => _ProfilePageState();
}


class _ProfilePageState extends State<ProfilePage> {

	@override
	Widget build(BuildContext context) {
		final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
		final String login = args['login'];
		final String token = args['token'];

		return Scaffold(
			body: Center(
				child: Text('Hello $login! Your token is $token'),
			)
		);
	}
}
