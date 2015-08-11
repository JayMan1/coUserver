part of coUserver;

class Metabolics {
	@Field()
	int id;

	@Field()
	int mood = 50;

	@Field()
	int max_mood = 100;

	@Field()
	int energy = 50;

	@Field()
	int max_energy = 100;

	@Field()
	int currants = 0;

	@Field()
	int img = 0;

	@Field()
	int lifetime_img = 0;

	@Field()
	String current_street = 'LA58KK7B9O522PC';

	@Field()
	num current_street_x = 1.0;

	@Field()
	num current_street_y = 0.0;

	@Field()
	int user_id = -1;

	@Field()
	int alphfavor = 0;
	@Field()
	int alphfavor_max = 1000;
	@Field()
	int cosmafavor = 0;
	@Field()
	int cosmafavor_max = 1000;
	@Field()
	int friendlyfavor = 0;
	@Field()
	int friendlyfavor_max = 1000;
	@Field()
	int grendalinefavor = 0;
	@Field()
	int grendalinefavor_max = 1000;
	@Field()
	int humbabafavor = 0;
	@Field()
	int humbabafavor_max = 1000;
	@Field()
	int lemfavor = 0;
	@Field()
	int lemfavor_max = 1000;
	@Field()
	int mabfavor = 0;
	@Field()
	int mabfavor_max = 1000;
	@Field()
	int potfavor = 0;
	@Field()
	int potfavor_max = 1000;
	@Field()
	int sprigganfavor = 0;
	@Field()
	int sprigganfavor_max = 1000;
	@Field()
	int tiifavor = 0;
	@Field()
	int tiifavor_max = 1000;
	@Field()
	int zillefavor = 0;
	@Field()
	int zillefavor_max = 1000;

	@Field(model:'location_history')
	String location_history_json = '[]';

	List<String> get location_history => JSON.decode(location_history_json);
	set location_history(List<String> history) {
		location_history_json = JSON.encode(history);
	}
}

class MetabolicsEndpoint {
	static bool simulateMood = false, simulateEnergy = false;
	static Timer moodTimer = new Timer.periodic(new Duration(seconds: 60), (Timer timer) => simulateMood = true);
	static Timer energyTimer = new Timer.periodic(new Duration(seconds: 90), (Timer timer) => simulateEnergy = true);
	static Timer simulateTimer = new Timer.periodic(new Duration(seconds: 5), (Timer timer) => simulate());
	static Map<String, WebSocket> userSockets = {};
	static Random rand = new Random();

	static Future refillAllEnergy() async {
		PostgreSql dbConn = await dbManager.getConnection();
		String query = "UPDATE metabolics SET energy = max_energy";
		dbConn.execute(query);
		dbManager.closeConnection(dbConn);
	}

	static void handle(WebSocket ws) {
		moodTimer.isActive;
		energyTimer.isActive;
		simulateTimer.isActive;

		ws.listen((message) => processMessage(ws, message),
		          onError: (error) => cleanupList(ws),
		          onDone: () => cleanupList(ws));
	}

	static void cleanupList(WebSocket ws) {
		String leavingUser;

		userSockets.forEach((String username, WebSocket socket) {
			if(ws == socket) {
				socket = null;
				leavingUser = username;
			}
		});

		userSockets.remove(leavingUser);
	}

	static void processMessage(WebSocket ws, String message) {
		Map map = JSON.decode(message);
		String username = map['username'];

		if(!userSockets.containsKey(username)) {
			userSockets[username] = ws;
		}
	}

	static void simulate() {
		userSockets.forEach((String username, WebSocket ws) async
		{
			try {
				Metabolics m = await getMetabolics(username:username);

				if(simulateMood) {
					_calcAndSetMood(m);
				}
				if(simulateEnergy) {
					_calcAndSetEnergy(m);
				}

				Identifier userIdentifier = PlayerUpdateHandler.users[username];

//				if (userIdentifier != null) {
//
//					if (userIdentifier.tsid.endsWith("A5PPFP86NF2FOS")) {
//						userIdentifier.outOfHell = false;
//					}
//
//					if (m.energy == 0 && !userIdentifier.dead && userIdentifier.outOfHell) {
//						// Dead, not in Hell
//						userIdentifier.undeadTSID = userIdentifier.tsid;
//						Map<String, String> map = {
//							"gotoStreet": "true",
//							"tsid": "LA5PPFP86NF2FOS", // Hell One
//							"dead": "true"
//						};
//						userIdentifier.webSocket.add(JSON.encode(map));
//						userIdentifier.dead = true;
//					} else if (m.energy > 0 && !userIdentifier.outOfHell && userIdentifier.dead) {
//						// Not Dead, but still in Hell
//						if (userIdentifier.undeadTSID == null) {
//							userIdentifier.undeadTSID = "LA58KK7B9O522PC"; // Cebarkul
//						}
//						Map<String, String> map = {
//							"gotoStreet": "true",
//							"tsid": userIdentifier.undeadTSID, // Street where they died
//							"dead": "false"
//						};
//						userIdentifier.webSocket.add(JSON.encode(map));
//						userIdentifier.dead = false;
//					}
//
//				}

				//store current street and position
				if(userIdentifier != null) {
					m.current_street = userIdentifier.tsid;
					m.current_street_x = userIdentifier.currentX;
					m.current_street_y = userIdentifier.currentY;

					//store the metabolics back to the database
					int result = await setMetabolics(m);
					if(result > 0) {
						//send the metabolics back to the user
						ws.add(JSON.encode(encode(m)));
					}
				}
			}
			catch(e, st) {
				log("(metabolics endpoint - simulate): $e\n$st");
			}
		});
	}

	static denyQuoin(Quoin q, String username) {
		Map map = {'collectQuoin':'true',
			'success':'false',
			'id':q.id};
		try {
			userSockets[username].add(JSON.encode(map));
		}
		catch(err) {
			log('(metabolics_endpoint_deny_quoin) Could not pass map $map to player $username: $err');
		}
	}

	static Future addQuoin(Quoin q, String username) async {
		int amt = rand.nextInt(4) + 1;
		int quoinMultiplier = 1;
		// TODO: change 1 to the real quoin multiplier
		amt = amt * quoinMultiplier;

		if(q.type == "quarazy") {
			amt *= 7;
		}

		Metabolics m = await getMetabolics(username:username);

		if(q.type == 'currant') {
			m.currants += amt;
		}
		if(q.type == 'img' || q.type == 'quarazy') {
			m.img += amt;
			m.lifetime_img += amt;
		}
		if(q.type == 'mood') {
			m.mood += amt;
			if(m.mood > m.max_mood) {
				m.mood = m.max_mood;
			}
		}
		if(q.type == 'energy') {
			m.energy += amt;
			if(m.energy > m.max_energy) {
				m.energy = m.max_energy;
			}
		}
		if(q.type == "favor") {
			m.alphfavor += amt;
			m.cosmafavor += amt;
			m.friendlyfavor += amt;
			m.grendalinefavor += amt;
			m.humbabafavor += amt;
			m.lemfavor += amt;
			m.mabfavor += amt;
			m.potfavor += amt;
			m.sprigganfavor += amt;
			m.tiifavor += amt;
			m.zillefavor += amt;
		}

		try {
			int result = await setMetabolics(m);
			if(result > 0) {
				Map map = {'collectQuoin':'true',
					'id':q.id,
					'amt':amt,
					'quoinType':q.type};

				q.setCollected();

				userSockets[username].add(JSON.encode(map));
				userSockets[username].add(JSON.encode(encode(m)));
			}
		}
		catch(err) {
			log('(metabolics_endpoint_add_quoin) Could not set metabolics $m for player $username: $err');
		}
	}

	static void _calcAndSetMood(Metabolics m) {
		int max_mood = m.max_mood;
		num moodRatio = m.mood / max_mood;

		//determine how much mood they should lose based on current percentage of max
		//https://web.archive.org/web/20130106191352/http://www.glitch-strategy.com/wiki/Mood
		if(moodRatio < .5)
			m.mood -= (max_mood * .005).ceil();
		else if(moodRatio >= .5 && moodRatio < .81)
			m.mood -= (max_mood * .01).ceil();
		else
			m.mood -= (max_mood * .015).ceil();

		if(m.mood < 0)
			m.mood = 0;

		simulateMood = false;
	}

	static void _calcAndSetEnergy(Metabolics m) {
		//players lose .8% of their max energy every 90 seconds
		//https://web.archive.org/web/20120805062536/http://www.glitch-strategy.com/wiki/Energy
		m.energy -= (m.max_energy * .008).ceil();

		if(m.energy < 0) {
			m.energy = 0;
		}

		simulateEnergy = false;
	}
}

@app.Route('/getMetabolics')
@Encode()
Future<Metabolics> getMetabolics({@app.QueryParam() String username, @app.QueryParam() String email}) async {
	Metabolics metabolic = new Metabolics();

	PostgreSql dbConn = await dbManager.getConnection();
	try {
		String whereClause = "WHERE users.username = @username";
		if(email != null) {
			whereClause = "WHERE users.email = @email";
		}
		String query = "SELECT * FROM metabolics JOIN users ON users.id = metabolics.user_id " + whereClause;
		List<Metabolics> metabolics = await dbConn.query(query, Metabolics, {'username':username, 'email':email});

		if(metabolics.length > 0) {
			metabolic = metabolics[0];
		} else {
			query = "SELECT * FROM users " + whereClause;
			var results = await dbConn.query(query, int, {'username':username, 'email':email});

			if(results.length > 0) {
				metabolic.user_id = results[0]['id'];
			}
		}

		dbManager.closeConnection(dbConn);
	} catch(e, st) {
		if(dbConn != null) {
			dbManager.closeConnection(dbConn);
		}
		log('(getMetabolics): $e\n$st');
	} finally {
		return metabolic;
	}
}

@app.Route('/setMetabolics', methods:const[app.POST])
Future<int> setMetabolics(@Decode() Metabolics metabolics) async {
	int result = 0;

	//try to not overset the metabolics that have maxes
	if(metabolics.mood > metabolics.max_mood) {
		metabolics.mood = metabolics.max_mood;
	}
	if(metabolics.energy > metabolics.max_energy) {
		metabolics.energy = metabolics.max_energy;
	}

	PostgreSql dbConn = await dbManager.getConnection();
	try {
		//if the user already exists, update their data, otherwise insert them
		String query = "SELECT user_id FROM metabolics WHERE user_id = @user_id";
		List<int> results = await dbConn.query(query, int, metabolics);

		//user exists
		if(results.length > 0) {
			query = "UPDATE metabolics SET img = @img, currants = @currants, mood = @mood, energy = @energy, lifetime_img = @lifetime_img, current_street = @current_street, current_street_x = @current_street_x, current_street_y = @current_street_y, max_energy = @max_energy, max_mood = @max_mood, alphfavor = @alphfavor,cosmafavor = @cosmafavor,friendlyfavor = @friendlyfavor,grendalinefavor = @grendalinefavor,humbabafavor = @humbabafavor,lemfavor = @lemfavor,mabfavor = @mabfavor,potfavor = @potfavor,sprigganfavor = @sprigganfavor,tiifavor = @tiifavor,zillefavor = @zillefavor,location_history = @location_history WHERE user_id = @user_id";
		} else {
			query = "INSERT INTO metabolics (img,currants,mood,energy,lifetime_img,user_id,current_street,current_street_x,current_street_y,max_energy,max_mood,alphfavor,cosmafavor,friendlyfavor,grendalinefavor,humbabafavor,lemfavor,mabfavor,potfavor,sprigganfavor,tiifavor,zillefavor,location_history) VALUES(@img,@currants,@mood,@energy,@lifetime_img,@user_id,@current_street,@current_street_x,@current_street_y,@max_energy,@max_mood,@alphfavor,@cosmafavor,@friendlyfavor,@grendalinefavor,@humbabafavor,@lemfavor,@mabfavor,@potfavor,@sprigganfavor,@tiifavor,@zillefavor,@location_history);";
		}

		result = await dbConn.execute(query, metabolics);

		dbManager.closeConnection(dbConn);
	}
	catch(e, st) {
		if(dbConn != null) {
			dbManager.closeConnection(dbConn);
		}
		log('(setMetabolics): $e\n$st');
	} finally {
		return result;
	}
}