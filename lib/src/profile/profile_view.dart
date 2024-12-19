import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

class UserService {

	static String? _token;
	static String _login = '';

	static void setToken(BuildContext context, String token) {
		if (token == '') {
			Navigator.pushNamed(context, '/search'); 
		}
		_token = token;
		print('Token set: $_token');
	}

	static void setLogin(BuildContext context, String login) {
		if (login == '') {
			Navigator.pushNamed(context, '/search'); 
		}
		_login = login;
		print('Login set: $_login');
	}

	static String? getToken() {
		return _token;
	}

	// get function to get user infos from the api
	static Future<Map<String, dynamic>> getUserInfos() async {
		final token = _token;
		if (token == null) {
			throw Exception('No token found');
		}

		final response = await http.get(
			Uri.parse('https://api.intra.42.fr/v2/users/$_login/cursus_users'),
			headers: {
				'Authorization': 'Bearer $token',
			},
		);

		if (response.statusCode != 200) {
			throw Exception('Failed to get user infos');
		}

		final coalitionJson = await getUserCoalition();

		final cursusUserJson = json.decode(response.body);

		final userJson = cursusUserJson[0]['user'];
		userJson['coalitionName'] = coalitionJson['name'];
		userJson['coalitionImageUrl'] = coalitionJson['image_url'];
		userJson['coalitionColor'] = coalitionJson['color'];
		userJson['cover_url'] = coalitionJson['cover_url'] ?? '';
		userJson['level'] =  cursusUserJson[0]['level'];
		userJson['skills'] = cursusUserJson[0]['skills'].map((skill) => {
			'name': skill['name'],
			'level': skill['level'],
		}).toList();

		return userJson;
	}

	static Future<Map<String, dynamic>> getUserCoalition() async {
		final token = _token;
		if (token == null) {
			throw Exception('No token found');
		}

		final coalitionResponse = await http.get(
			Uri.parse('https://api.intra.42.fr/v2/users/$_login/coalitions'),
			headers: {
				'Authorization': 'Bearer $token',
			},
		);

		if (coalitionResponse.statusCode != 200) {
			throw Exception('Failed to get user coalition infos');
		}

		final coalitionJson = json.decode(coalitionResponse.body);

		final coalition = coalitionJson[coalitionJson.length - 1];

		return coalition;
	}

	static Future<List<dynamic>> getUserProjects() async {
		final token = _token;
		if (token == null) {
			throw Exception('No token found');
		}

		print('Getting user projects for $_login');

		final response = await http.get(
			Uri.parse('https://api.intra.42.fr/v2/users/$_login/projects_users?page[size]=100'),
			headers: {
				'Authorization': 'Bearer $token',
			},
		);

		if (response.statusCode != 200) {
			throw Exception('Failed to get user projects');
		}

		final projectsJson = json.decode(response.body);

		final projects = projectsJson.map((project) => {
			'name': project['project']['name'],
			'slug': project['project']['slug'],
			'final_mark': project['final_mark'],
			'status': project['status'],
			'validated?': project['validated?'],
			'image_url': project['project']['image_url'],
			'created_at': project['created_at'],
		}).toList();

		projects.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));

		return projects;
	}
}

class UserInfos {
	final int cursusId;
	final String login;
	final String email;
	final String firstName;
	final String lastName;
	final String phone;
	final String imageUrl;
	final int correctionPoint;
	final int wallet;
	final String poolYear;
	final String coalitionName;
	final String coalitionImageUrl;
	final String coalitionColor;
	final String coverUrl;
	final double level;
	List<UserProject> projects;
	List<UserSkills> skills;

	UserInfos({
		required this.cursusId,
		required this.login,
		required this.email,
		required this.firstName,
		required this.lastName,
		required this.phone,
		required this.imageUrl,
		required this.correctionPoint,
		required this.wallet,
		required this.poolYear,
		this.coalitionName = '',
		this.coalitionImageUrl = '',
		this.coalitionColor = '',
		this.coverUrl = '',
		this.level = 0,
		this.projects = const [],
		this.skills = const [],
	});

	factory UserInfos.fromJson(Map<String, dynamic> json) {
		return UserInfos(
			cursusId: json['cursus_id'] ?? 0,
			login: json['login'] ?? '',
			email: json['email'] ?? '',
			firstName: json['first_name'] ?? '',
			lastName: json['last_name'] ?? '',
			phone: json['phone'] ?? '',
			imageUrl: json['image']['link'] ?? '',
			correctionPoint: json['correction_point'] ?? 0,
			wallet: json['wallet'] ?? 0,
			poolYear: json['pool_year'] ?? '',
			coalitionName: json['coalitionName'] ?? '',
			coalitionImageUrl: json['coalitionImageUrl'] ?? '',
			coalitionColor: json['coalitionColor'] ?? '',
			coverUrl: json['cover_url'] ?? '',
			level: json['level'] ?? 0,
			projects: [],
			skills: json['skills'].map<UserSkills>((skill) => UserSkills.fromJson(skill)).toList(),
		);
	}
}

class UserProject {
	final String name;
	final String slug;
	final int finalMark;
	final String status;
	final bool validated;
	final String projectImageUrl;
	final String createdAt;

	UserProject({
		required this.name,
		required this.slug,
		required this.finalMark,
		required this.status,
		required this.validated,
		required this.projectImageUrl,
		required this.createdAt,
	});

	factory UserProject.fromJson(Map<String, dynamic> json) {
		return UserProject(
			name: json['name'] ?? '',
			slug: json['slug'] ?? '',
			finalMark: json['final_mark'] ?? 0,
			status: json['status'] ?? '',
			validated: json['validated?'] ?? false,
			projectImageUrl: json['image_url'] ?? '',
			createdAt: json['created_at'] ?? '',
		);
	}
}

class UserSkills {
	final String name;
	final double level;

	UserSkills({
		required this.name,
		required this.level,
	});

	factory UserSkills.fromJson(Map<String, dynamic> json) {
		return UserSkills(
			name: json['name'] ?? '',
			level: json['level'] ?? 0,
		);
	}
}

enum ProfileCategory {
	info,
	projects,
	skills,
	achievements
}

class ProfilePage extends StatefulWidget {
	const ProfilePage({super.key});
	static const String routeName = '/profile';

	@override
	_ProfilePageState createState() => _ProfilePageState();
}


class _ProfilePageState extends State<ProfilePage> {
	UserInfos? _user;
  	bool _isLoading = true;
	ProfileCategory _selectedCategory = ProfileCategory.info;

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		_loadUserData();
	}

	void _changeCategory(ProfileCategory category) async {
		setState(() {
			_selectedCategory = category;
		});

		if (category == ProfileCategory.projects) {
			if (_user != null && _user!.projects.isNotEmpty) {
				return;
			}
			setState(() {
				_isLoading = true;
			});
			final projectsJson = await UserService.getUserProjects();
			_user?.projects = projectsJson.map((project) => UserProject.fromJson(project)).toList();
			setState(() {
				_isLoading = false;
			});
		}
	}


	Future<void> _loadUserData() async {
		if (!mounted) return;

		final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
		final String login = args['login'];
		final String token = args['token'];

		UserService.setToken(context, token);
		UserService.setLogin(context, login);

		try {
			final userData = await UserService.getUserInfos();
			if (mounted) {
				setState(() {
					_user = UserInfos.fromJson(userData);
					_isLoading = false;
				});
			}
		} catch (e) {
			if (mounted) {
				setState(() {
					_isLoading = false;
				});
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Error loading user data: ${e.toString()}')),
				);
			}
		}
	}

	Widget _buildCategoryIcon(ProfileCategory category) {
		final bool isSelected = _selectedCategory == category;
		
		IconData icon;
		switch (category) {
			case ProfileCategory.info:
				icon = Icons.info;
				break;
			case ProfileCategory.projects:
				icon = Icons.article;
				break;
			case ProfileCategory.skills:
				icon = Icons.star;
				break;
			case ProfileCategory.achievements:
				icon = Icons.emoji_events;
				break;
		}

		return InkWell(
			onTap: () => _changeCategory(category),
			child: Container(
				padding: const EdgeInsets.all(10),
				decoration: BoxDecoration(
					color: isSelected ? _user!.coalitionColor.isNotEmpty ? Color(int.parse('0xFF${_user!.coalitionColor.replaceAll('#', '')}')).withOpacity(0.3): Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.1),
					borderRadius: BorderRadius.circular(5),
					border: Border.all(color: isSelected ? Colors.white70 : Colors.transparent, width: 2),
				),
				child: Icon(icon),
			),
		);
	}

	Widget _buildInfoContent() {
		return Column(
			children: [
				Column(
					children: [
						Container(
							width: 75,
							height: 75,
							padding: const EdgeInsets.all(10),
							decoration: BoxDecoration(
								color: _user!.coalitionColor.isNotEmpty ? Color(int.parse('0xFF${_user!.coalitionColor.replaceAll('#', '')}')) : Colors.grey,
								borderRadius: BorderRadius.circular(25),
							),
							child: SvgPicture.network(
								_user!.coalitionImageUrl,
								width: 30,
								height: 30,
							)
						),
						const SizedBox(height: 10),
						Text(
							_user!.coalitionName,
							style: const TextStyle(
								fontSize: 20,
								fontWeight: FontWeight.w600,
							),
						),
					],
				),
				const SizedBox(height: 20),
				Row(
					children: [
						Icon(Icons.email, color: Colors.white70),
						const SizedBox(width: 10),
						Text(
							_user!.email,
							style: const TextStyle(
								color: Colors.white70,
							),
						),
					],
				),
				const SizedBox(height: 10),
				Row(
					children: [
						Icon(Icons.phone, color: Colors.white70),
						const SizedBox(width: 10),
						Text(
							_user!.phone,
							style: const TextStyle(
								color: Colors.white70,
							),
						),
					],
				),
				const SizedBox(height: 10),
				Row(
					children: [
						Icon(Icons.account_balance_wallet, color: Colors.white70),
						const SizedBox(width: 10),
						Text(
							'${_user!.wallet}₳',
							style: const TextStyle(
								color: Colors.white70,
							),
						),
					],
				),
				const SizedBox(height: 10),
				Row(
					children: [
						Icon(Icons.check, color: Colors.white70),
						const SizedBox(width: 10),
						Text(
							'${_user!.correctionPoint} points',
							style: const TextStyle(
								color: Colors.white70,
							),
						),
					],
				),
				const SizedBox(height: 10),
				Row(
					children: [
						Icon(Icons.school, color: Colors.white70),
						const SizedBox(width: 10),
						Text(
							'${_user!.poolYear} pool',
							style: const TextStyle(
								color: Colors.white70,
							),
						),
					],
				),
			],
		);
	}

	Widget _buildSkillsContent() {
		// list of skills
		return ListView.builder(
			padding: const EdgeInsets.all(5),
			shrinkWrap: true,
			physics: NeverScrollableScrollPhysics(),
			itemCount: _user!.skills.length,
			itemBuilder: (context, index) {
				final skill = _user!.skills[index];
				return _buildSkillChip(skill.name, skill.level);
			},
		);
	}

	Widget _buildSkillChip(String name, double level) {
		return Container(
			padding: EdgeInsets.all(8.0),
			margin: EdgeInsets.only(right: 15, bottom: 15),
			decoration: BoxDecoration(
				color: Colors.white.withOpacity(0.1),
				borderRadius: BorderRadius.circular(10),
			),
			child: 
				Column(
					children: [
						Text(name, style: TextStyle(color: Colors.white, fontSize: 16)),
						SizedBox(height: 20),
						Container(
							width: 300,
							height: 10,
							decoration: BoxDecoration(
								color: Colors.grey.withOpacity(0.3),
								borderRadius: BorderRadius.circular(5),
							),
							child: FractionallySizedBox(
								widthFactor: level / 20,
								child: Container(
									decoration: BoxDecoration(
									color: _user?.coalitionColor.isNotEmpty ?? false
										? Color(int.parse('0xFF${_user!.coalitionColor.replaceAll('#', '')}'))
										: Colors.blueAccent,
									borderRadius: BorderRadius.circular(2.5),
									),
								),
							),
						),
						SizedBox(height: 10),
						Text(
							'Level $level',
							style: TextStyle(color: Colors.white70),
						)
					],
				)
		);
	}

	Widget _buildAchievementsContent() {
		return GridView.count(
			shrinkWrap: true,
			physics: NeverScrollableScrollPhysics(),
			crossAxisCount: 2,
			childAspectRatio: 1.5,
			children: List.generate(4, (index) {
				return Card(
					color: Colors.white.withOpacity(0.1),
					child: Column(
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							Icon(Icons.emoji_events, color: Colors.amber),
							SizedBox(height: 8),
							Text(
								'Achievement ${index + 1}',
								style: TextStyle(color: Colors.white),
							),
						],
					),
				);
			}),
		);
	}

	Widget _buildProjectsContent() {
		return Card(
			color: Colors.white.withOpacity(0.1),
			child: ListView.builder(
				padding: const EdgeInsets.all(5),
				shrinkWrap: true,
				physics: NeverScrollableScrollPhysics(),
				itemCount: _user!.projects.length,
				itemBuilder: (context, index) {
					final project = _user!.projects[index];
					return ListTile(
						title: Text(project.name, style: TextStyle(color: project.finalMark > 100 ? Color(int.parse('0xFF${_user!.coalitionColor.replaceAll('#', '')}')) : Colors.white)),
						subtitle: Text('${project.status == "finished" ? project.finalMark : project.status} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(project.createdAt))}', style: TextStyle(color: Colors.white70)),
						leading: Icon(Icons.folder, color: project.finalMark > 100 ? Color(int.parse('0xFF${_user!.coalitionColor.replaceAll('#', '')}')) : Colors.grey),
					);
				},
			),
		);
	}

	Widget _buildCategoryContent() {
		switch (_selectedCategory) {
			case ProfileCategory.info:
				return _buildInfoContent();
			case ProfileCategory.projects:
				return _buildProjectsContent();
			case ProfileCategory.skills:
				return _buildSkillsContent();
			case ProfileCategory.achievements:
				return _buildAchievementsContent();
		}
	}

	@override
	Widget build(BuildContext context) {

		return Scaffold(
			body: Stack(
				fit: StackFit.expand,
				children: [
					_user != null && _user!.coverUrl != ''
						? Image.network(
							_user!.coverUrl,
							fit: BoxFit.cover,
							opacity: AlwaysStoppedAnimation(0.1),
						)
						: Container(
							color: Colors.grey,
							width: double.infinity,
						),
					_user != null
						? 
						Stack(
							fit: StackFit.expand,
							children: [
								SingleChildScrollView(
									// padding to the top of the screen and on the sides
									padding: const EdgeInsets.only(top: 75, left: 20, right: 20),

									child: Column(
										children: [
											_user!.imageUrl != ''
												? CircleAvatar(
													radius: 75,
													backgroundImage: NetworkImage(_user!.imageUrl),
												)
												: const FlutterLogo(size: 100),
											const SizedBox(height: 20),
											Row(
												mainAxisAlignment: MainAxisAlignment.center,
												children: [
													Text(
														_user!.login,
														style: const TextStyle(
															fontSize: 20,
															fontWeight: FontWeight.w600,
														),
													),
												],
											),
											const SizedBox(height: 20),
											Row(
												children: [
													Column(
														children:[
															Container(
																width: 350,
																height: 10,
																decoration: BoxDecoration(
																	color: Colors.grey.withOpacity(0.3),
																	borderRadius: BorderRadius.circular(5),
																),
																child: Align(
																	alignment: Alignment.centerLeft,
																	child: Container(
																		width: ((_user!.level - _user!.level.floor()) * 100).round() * 3.5,
																		decoration: BoxDecoration(
																			color: _user!.coalitionColor.isNotEmpty ? Color(int.parse('0xFF${_user!.coalitionColor.replaceAll('#', '')}')) : Colors.blueAccent,
																			borderRadius: BorderRadius.circular(5),
																		),
																	),
																),
															),
															const SizedBox(height: 10),
															Text(
																'Level ${_user!.level.floor()} - ${(_user!.level - _user!.level.floor()).toStringAsFixed(2).substring(2)}%',
																style: const TextStyle(
																	fontSize: 16,
																	fontWeight: FontWeight.w600,
																	color: Colors.white70,
																),
															),
														]
													)
												]
											),
											const SizedBox(height: 30),
											Row(
												mainAxisAlignment: MainAxisAlignment.spaceEvenly,
												children: [
													_buildCategoryIcon(ProfileCategory.info),
													_buildCategoryIcon(ProfileCategory.projects),
													_buildCategoryIcon(ProfileCategory.skills),
													_buildCategoryIcon(ProfileCategory.achievements),
												],
											),
											const SizedBox(height: 15),
											// line separator
											Container(
												height: 5,
												color: Colors.white.withOpacity(0.1),
											),
											const SizedBox(height: 15),
											_buildCategoryContent()
										]
									),
								),
							]
						)
						:
						const Center(
							child: CircularProgressIndicator(),
						),
					]
				)
			);
	}
}
