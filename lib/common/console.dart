library console;

import 'dart:async';
import 'dart:io';

import 'package:coUserver/common/util.dart';
import 'package:coUserver/endpoints/stats.dart';
import 'package:coUserver/endpoints/status.dart';

class Console {
	static Map<String, Command> _commands = new Map();

	static StreamSubscription _handler;

	static void init() {
		// Graceful shutdown
		ProcessSignal.SIGINT.watch().listen((ProcessSignal sig) async => await cleanup());
		ProcessSignal.SIGTERM.watch().listen((ProcessSignal sig) async => await cleanup());

		stdin.echoMode = true;
		stdin.lineMode = true;

		_handler?.cancel();
		_handler = stdin.listen((List<int> chars) async {
			String input = new String.fromCharCodes(chars).trim();
			if (input.length > 0) {
				log('> $input');
				try {
					await _runCommand(input);
				} catch (e) {
					log('Error running command: $e');
				}
			}
		});

		new Command.register('help', () {
			StringBuffer help = new StringBuffer()
				..writeln('List of commands & arguments:');
			for (Command command in _commands.values) {
				help.writeln('* $command');
			}
			log(help.toString().trim());
		});

		new Command.register('stats', () async {
			log(Console.formatMap(await StatManager.getAllSums()));
		});

		new Command.register('status', () async {
			log(Console.formatMap(await getServerStatus()));
		});

		new Command.register('stop', (String exitCode) async {
			await cleanup(int.parse(exitCode));
		}, ['exit code']);

		new Command.register('migrate', (String object) async {
			final Map<String, Function> _MIGRATES = {
				'entities': () async => await StreetEntities.migrateEntities()
			};

			if (_MIGRATES.keys.contains(object)) {
				log('Migrating $object...');
				int migrated = await _MIGRATES[object]();
				log('Migration of $migrated $object completed!');
			} else {
				log('No migrateable object "$object"');
			}
		}, ['object to migrate']);
	}

	static String formatMap(Map input) {
		StringBuffer output = new StringBuffer();
		input.forEach((key, value) {
			output.writeln('$key: $value');
		});
		return output.toString().trim();
	}

	static void registerCommand(Command command) {
		if (_commands.containsKey(command.name)) {
			throw 'Command ${command.name} already registered';
		} else {
			_commands[command.name] = command;
		}
	}

	static Future<dynamic> _runCommand(String input) async {
		List<String> parts = input.split(' ');
		String name = parts.first;
		List<String> args = parts.sublist(1);

		if (!_commands.containsKey(name)) {
			throw 'Command $name not found';
		} else {
			return await _commands[name].call(args);
		}
	}
}

class Command {
	String _name;
	List<String> _arguments;
	Function _function;

	String get name => _name;

	Command(String name, Function function, [List<String> arguments]) {
		_name = name;
		_arguments = arguments ?? new List();
		_function = function;
	}

	Command.register(String name, Function function, [List<String> arguments]) {
		Console.registerCommand(new Command(name, function, arguments));
	}

	Future<dynamic> call(List<String> arguments) async {
		if (arguments.length != _arguments.length) {
			throw 'Incorrect number of arguments provided to $_name';
		}

		return await Function.apply(_function, arguments);
	}

	@override
	String toString() {
		String argFmt = (_arguments.length == 0 ? '' : '<${_arguments.join(', ')}>');
		return '$_name $argFmt';
	}
}
