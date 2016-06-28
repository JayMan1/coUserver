library user;

import 'dart:async';

import 'package:coUserver/common/util.dart';

import 'package:redstone_mapper/mapper.dart';
import 'package:redstone_mapper_pg/manager.dart';

class User {
	@Field() int id;
	@Field() String username, email, bio, achievements, elevation, custom_avatar;
	@Field() bool chat_disabled;
	@Field() DateTime last_login;

	static Map<String, String> _emailUsernames = {};
	static Map<String, String> _usernameEmails = {};
	static Map<int, String> _idUsernames = {};
	static Map<String, int> _usernameIds = {};

	static void _updateMaps(User u) {
		_emailUsernames[u.email] = u.username;
		_idUsernames[u.id] = u.username;
		_usernameEmails[u.username] = u.email;
		_usernameIds[u.email] = u.id;
	}

	static Future<String> getUsernameFromEmail(String email) async {
		if (_emailUsernames[email] != null) {
			return _emailUsernames[email];
		} else {
			PostgreSql dbConn = await dbManager.getConnection();
			try {
				String query = "SELECT * FROM users WHERE email = @email";
				User u = (await dbConn.query(query, User, {"email": email})).first;
				_updateMaps(u);
			} catch (e, st) {
				Log.error('Error getting username for <email=$email>', e, st);
			} finally {
				dbManager.closeConnection(dbConn);
			}

			return _emailUsernames[email];
		}
	}

	static Future<String> getEmailFromUsername(String username) async {
		if (_usernameEmails[username] != null) {
			return _usernameEmails[username];
		} else {
			PostgreSql dbConn = await dbManager.getConnection();
			try {
				String query = "SELECT * FROM users WHERE username = @username";
				User u = (await dbConn.query(query, User, {"username": username})).first;
				_updateMaps(u);
			} catch (e, st) {
				Log.error('Error getting email for username $username', e, st);
			} finally {
				dbManager.closeConnection(dbConn);
			}

			return _usernameEmails[username];
		}
	}

	static Future<String> getUsernameFromId(int id) async {
		if (_idUsernames[id] != null) {
			return _idUsernames[id];
		} else {
			PostgreSql dbConn = await dbManager.getConnection();
			try {
				String query = "SELECT * FROM users WHERE id = @id";
				User u = (await dbConn.query(query, User, {"id": id})).first;
				_updateMaps(u);
			} catch (e, st) {
				Log.error('Error getting username for id $id', e, st);
			} finally {
				dbManager.closeConnection(dbConn);
			}

			return _idUsernames[id];
		}
	}

	static Future<int> getIdFromEmail(String email) async {
		if (_usernameIds[email] != null) {
			return _usernameIds[email];
		} else {
			PostgreSql dbConn = await dbManager.getConnection();
			try {
				String query = "SELECT * FROM users WHERE email = @email";
				User u = (await dbConn.query(query, User, {"email": email})).first;
				_updateMaps(u);
			} catch (e, st) {
				Log.error('Error getting id for <email=$email>', e, st);
			} finally {
				dbManager.closeConnection(dbConn);
			}

			return _usernameIds[email];
		}
	}
}
