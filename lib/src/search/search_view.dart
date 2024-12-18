import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthService {
	static const _tokenKey = 'accessToken';
	static const _tokenExpiryKey = 'tokenExpiry';

	static Future<String?> getStoredToken() async {
		final prefs = await SharedPreferences.getInstance();
		final token = prefs.getString(_tokenKey);
    	final expiry = prefs.getInt(_tokenExpiryKey);

		if (token == null || expiry == null) {
			return null;
		}

		final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
		if (currentTime < expiry) {
			print('Token is still valid: $token');
			return token;
		}
		print('Token has expired. Current: $currentTime, Expiry: $expiry');
    	return null;
	}

	static Future<void> storeToken(String token, int expiresIn) async {
		final prefs = await SharedPreferences.getInstance();
		final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
		
		await prefs.setString(_tokenKey, token);
		await prefs.setInt(_tokenExpiryKey, currentTime + expiresIn);
	}

	static Future<String> fetchNewToken() async {
		final clientId = dotenv.env['CLIENT_ID'];
		final clientSecret = dotenv.env['CLIENT_SECRET'];

		print('Fetching new token...');
		final tokenResponse = await http.post(
			Uri.parse('https://api.intra.42.fr/oauth/token'),
			body: {
				'grant_type': 'client_credentials',
				'client_id': clientId,
				'client_secret': clientSecret,
			},
		);

		if (tokenResponse.statusCode != 200) {
			throw Exception('Failed to obtain access token');
		}

		final responseBody = json.decode(tokenResponse.body);
		final token = responseBody['access_token'];
		final expiresIn = responseBody['expires_in'];

		await storeToken(token, expiresIn);

		return token;
	}

	static Future<String> getToken() async {
		final storedToken = await getStoredToken();
		if (storedToken != null) {
			return storedToken;
		}
		return await fetchNewToken();
	}
}

class UserModel {
	final String login;
	final String? imageUrl;

	UserModel({
		required this.login,
		this.imageUrl,
	});

	factory UserModel.fromJson(Map<String, dynamic> json) {
		return UserModel(
			login: json['login'],
			imageUrl: json['image']?['link'],
		);
	}
}

class LoginPage extends StatefulWidget {
	const LoginPage({super.key});
	final routeName = '/';

	@override
	_LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
	final TextEditingController _searchController = TextEditingController();
	
	List<UserModel> _users = [];
	
	bool _isLoading = false;
	
	Future<void> searchUsers() async {
		print('Searching for users...');
		if (_searchController.text.trim().isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Please enter a login name')),
			);
			return;
		}

		setState(() {
			_isLoading = true;
			_users = [];
		});

		try {
			final accessToken = await AuthService.getToken();
			print('Access token: $accessToken');

			final searchResponse = await http.get(
				Uri.parse('https://api.intra.42.fr/v2/users?search[login]=${_searchController.text}%&page[size]=10'),
				headers: {
					'Authorization': 'Bearer $accessToken',
				},
			);
			print('Search response: ${searchResponse.statusCode}');
			if (searchResponse.statusCode == 200) {
				final List<dynamic> usersJson = json.decode(searchResponse.body);

				setState(() {
					_users = usersJson.map((userJson) => UserModel.fromJson(userJson)).toList();
					_isLoading = false;
				});
			} else if (searchResponse.statusCode == 401) {
				final newToken = await AuthService.fetchNewToken();
				print('New access token: $newToken');
				
				final retryResponse = await http.get(
					Uri.parse('https://api.intra.42.fr/v2/users?search[login]=${_searchController.text}%&page[size]=10'),
					headers: {
						'Authorization': 'Bearer $newToken',
					},
				);
				if (retryResponse.statusCode == 200) {
					final List<dynamic> usersJson = json.decode(retryResponse.body);
          
					setState(() {
						_users = usersJson.map((userJson) => UserModel.fromJson(userJson)).toList();
						_isLoading = false;
					});
				} else {
					throw Exception('Failed to search users after token refresh');
				}
			} else {
				throw Exception('Failed to search users');
			}
		} catch (e) {
			setState(() {
				_isLoading = false;
			});
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Error: ${e.toString()}')),
			);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			body: Stack(
				fit: StackFit.expand,
				children: [
					Image.asset(
						'assets/images/home.jpg',
						fit: BoxFit.cover,
					),
					
					Center(
						child: ClipRRect(
							borderRadius: BorderRadius.circular(20),
							child: BackdropFilter(
								filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
								child: Container(
									width: 350,
									padding: EdgeInsets.all(20),
									decoration: BoxDecoration(
										color: Colors.black.withOpacity(0.4),
										borderRadius: BorderRadius.circular(20),
									),
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											Text(
												'User Search',
												style: TextStyle(
												color: Colors.white,
												fontSize: 24,
												fontWeight: FontWeight.bold,
												),
											),
											SizedBox(height: 20),
											Row(
												children: [
													Expanded(
														child: TextField(
														controller: _searchController,
														decoration: InputDecoration(
															hintText: 'Enter login name',
															hintStyle: TextStyle(color: Colors.white70),
															filled: true,
															fillColor: Colors.white.withOpacity(0.2),
															border: OutlineInputBorder(
																borderRadius: BorderRadius.circular(10),
																borderSide: BorderSide.none,
															),
														),
														style: TextStyle(color: Colors.white),
														),
													),
													SizedBox(width: 10),
													Container(
														decoration: BoxDecoration(
															color: Colors.white.withOpacity(0.2),
															borderRadius: BorderRadius.circular(10),
														),
														child: IconButton(
															icon: _isLoading 
																? CircularProgressIndicator(color: Colors.white)
																: Icon(Icons.search, color: Colors.white),
															onPressed: _isLoading ? null : searchUsers,
														),
													),
												],
											),
											SizedBox(height: 20),
											if (_isLoading)
												CircularProgressIndicator(color: Colors.white)
											else if (_users.isNotEmpty)
												ConstrainedBox(
												constraints: BoxConstraints(
													maxHeight: 300,
												),
												child: ListView.builder(
													shrinkWrap: true,
													padding: EdgeInsets.zero,
													itemCount: _users.length,
													itemBuilder: (context, index) {
													final user = _users[index];
													return Container(
														margin: EdgeInsets.symmetric(vertical: 5),
														decoration: BoxDecoration(
															color: Colors.white.withOpacity(0.1),
															borderRadius: BorderRadius.circular(10),
														),
														child: ListTile(
															leading: user.imageUrl != null
																? CircleAvatar(
																	backgroundImage: NetworkImage(user.imageUrl!),
																)
																: CircleAvatar(
																	child: Icon(Icons.person, color: Colors.white),
																	backgroundColor: Colors.grey,
																),
															title: Text(
																user.login,
																style: TextStyle(color: Colors.white),
															),
														),
													);
													},
												),
												)
											else
												Text(
													'No users found',
													style: TextStyle(color: Colors.white),
												),
										],
									),
								),
							),
						),
					),
				],
			),
		);
	}
}