part of coUserver;

// handle chat events
class ChatHandler 
{
	static Map<String, WebSocket> userSockets = new Map<String,WebSocket>(); // Map of current users
	static List<Identifier> users = new List();
	
	static void handle(WebSocket ws)
	{
		/**we are no longer using heroku so this should not be necessary**/
		//if a heroku app does not send any information for more than 55 seconds, the connection will be terminated
		//new KeepAlive().start(ws); 
		
		ws.listen((message)
		{
			Map map = JSON.decode(message);
			if(relay.connected)
			{
				//don't repeat /list messages to the relay
				//or possibly any statusMessages, but we'll see
				if(map['statusMessage'] == null || map['statusMessage'] != "list")
					relay.sendMessage(message);
			}
			if(relay.slackConnected && map["channel"] == "Global Chat")
			{
				if(map["statusMessage"] == null && map["username"] != null && map["message"] != null)
					relay.slackSend(map["username"] + ":: " + map["message"]);
			}
			processMessage(ws, message);
	    }, 
		onError: (error)
		{
			cleanupLists(ws);
		}, 
		onDone: ()
		{
			cleanupLists(ws);
		});
	}
	
	static void cleanupLists(WebSocket ws)
	{
		List<String> socketRemove = new List<String>();
		List<int> usersRemove = new List<int>();
		String leavingUser, channel;
		userSockets.forEach((String username, WebSocket socket)
		{
			if(socket == ws)
			{
				socketRemove.add(username);
				leavingUser = username;
				users.removeWhere((Identifier userId) => userId.username == leavingUser);
			}
		});
		//let's set to null instead of removing to see if that solves concurrent modification exception 
		//when sending messages while a user disconnects
		socketRemove.forEach((String username)
		{
			userSockets[username] = null;
		});
		
		//send a message to all other clients that this user has disconnected
		Map map = new Map();
		map["message"] = " left.";
		map["username"] = leavingUser;
		map["channel"] = "Global Chat";
		sendAll(JSON.encode(map));
	}

	static void processMessage(WebSocket ws, String receivedMessage) 
	{
		try 
		{
			Map map = JSON.decode(receivedMessage);
			
			if(map["statusMessage"] == "join") 
			{
				userSockets[map["username"]] = ws;
				map["statusMessage"] = "true";
				map["username"] = map["username"];
    			map["message"] = ' joined.';
				String street = "";
				users.add(new Identifier(map["username"],street));
  			}
			else if(map["statusMessage"] == "changeName")
			{
				bool success = true;
				users.forEach((Identifier userId)
				{
					if(userId.username == map["newUsername"])
						success = false;
				});
				
				if(!success)
				{
					Map errorResponse = new Map();
					errorResponse["statusMessage"] = "changeName";
					errorResponse["success"] = "false";
					errorResponse["message"] = "This name is already taken.  Please choose another.";
					errorResponse["channel"] = map["channel"];
					userSockets[map["username"]].add(JSON.encode(errorResponse));
					return;
				}
				else
				{
					map["success"] = "true";
					map["message"] = "is now known as";
					map["channel"] = "all"; //echo it back to all channels so we can update the connectedUsers list on the client's side
					
					users.forEach((Identifier userId)
					{
						if(userId.username == map["username"]) //update the old usernames
						{
							userSockets[map["newUsername"]] = userSockets.remove(userId.username);
							userId.username = map["newUsername"];
						}
					});
				}
			}
			else if(map["statusMessage"] == "changeStreet")
			{
				users.forEach((Identifier id)
				{
					if(id.username == map["username"])
						id.currentStreet = map["newStreetLabel"];
					if(id.username != map["username"] && id.currentStreet == map["oldStreet"]) //others who were on the street with you
					{
						if(userSockets[id.username+"_"+"Local Chat"] == null)
							return;
						
						Map leftForMessage = new Map();
						leftForMessage["statusMessage"] = "leftStreet";
						leftForMessage["username"] = map["username"];
						leftForMessage["streetName"] = map["newStreetLabel"];
						leftForMessage["tsid"] = map["newStreetTsid"];
						leftForMessage["message"] = " has left for ";
						leftForMessage["channel"] = "Local Chat";
						userSockets[id.username].add(JSON.encode(leftForMessage));
						
					}
					if(id.currentStreet == map["newStreet"] && id.username != map["username"]) //others who are on the new street
					{
						//display message to others that we're here?
					}
				});
				return;
			}
			else if(map["statusMessage"] == "list")
			{
				List<String> userList = new List();
				users.forEach((Identifier userId)
				{
					if(!userList.contains(userId.username))
					{
						if(map["channel"] == "Local Chat" && userId.currentStreet == map["street"])
							userList.add(userId.username);
						else if(map["channel"] != "Local Chat")
							userList.add(userId.username);
					}
				});
				map["users"] = userList;
				map["message"] = "Users in this channel: ";
				userSockets[map["username"]].add(JSON.encode(map));
				return;
			}
			
      		sendAll(JSON.encode(map));
    	} 
		catch(err, st) 
		{
      		print('${new DateTime.now().toString()} - Exception - ${err.toString()}');
      		print(st);
    	}
	}

  	static void sendAll(String sendMessage)
	{
		Iterator itr = userSockets.values.iterator;
		while(itr.moveNext())
		{
			WebSocket socket = itr.current;
			if(socket != null)
				socket.add(sendMessage);
		}
  	}
}