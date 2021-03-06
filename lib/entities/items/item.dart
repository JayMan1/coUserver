library item;

import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io';

import 'package:coUserver/achievements/achievements.dart';
import 'package:coUserver/achievements/stats.dart';
import 'package:coUserver/buffs/buffmanager.dart';
import 'package:coUserver/common/identifier.dart';
import 'package:coUserver/common/mapdata/mapdata.dart';
import 'package:coUserver/common/user.dart';
import 'package:coUserver/common/util.dart';
import 'package:coUserver/endpoints/chat_handler.dart';
import 'package:coUserver/endpoints/inventory_new.dart';
import 'package:coUserver/endpoints/metabolics/metabolics.dart';
import 'package:coUserver/entities/entity.dart';
import 'package:coUserver/entities/items/actions/recipes/recipe.dart';
import 'package:coUserver/quests/quest.dart';
import 'package:coUserver/skills/skillsmanager.dart';
import 'package:coUserver/streets/player_update_handler.dart';
import 'package:coUserver/streets/street_update_handler.dart';
import 'package:coUserver/streets/street.dart';

import 'package:path/path.dart' as path;
import 'package:redstone_mapper_pg/manager.dart';
import 'package:redstone_mapper/mapper.dart';
import 'package:redstone/redstone.dart' as app;

part 'actions/itemgroups/baby_animals.dart';
part 'actions/itemgroups/consume.dart';
part 'actions/itemgroups/cubimals.dart';
part 'actions/itemgroups/emblems-icons.dart';
part 'actions/itemgroups/foxbait.dart';
part 'actions/itemgroups/grain_bushel.dart';
part 'actions/itemgroups/milk-butter-cheese.dart';
part 'actions/itemgroups/misc.dart';
part 'actions/itemgroups/orb.dart';
part 'actions/itemgroups/piggy_plop.dart';
part 'actions/itemgroups/potions.dart';
part 'actions/itemgroups/quill.dart';
part 'actions/itemgroups/recipe-tool.dart';
part 'actions/note.dart';
part 'package:coUserver/entities/action.dart';

Map<String, Item> items = {};

class Item extends Object
	with
		MetabolicsChange,
		BabyAnimals,
		Consumable,
		Cubimal,
		CubimalBox,
		Emblem,
		FocusingOrb,
		FoxBaitItem,
		GrainBushel,
		Icon,
		MilkButterCheese,
		NewPlayerPack,
		PiggyPlop,
		Potions,
		Quill,
		RecipeTool implements Actionable {

	Future<List<Action>> customizeActions(String email) async {
		return actions;
	}

	// Load item data from JSON files
	static Future<int> loadItems() async {
		String filePath = path.join(serverDir.path, 'lib', 'entities', 'items', 'json');
		await Future.forEach(await new Directory(filePath).list().toList(), (File cat) async {
			JSON.decode(await cat.readAsString()).forEach((String name, Map itemMap) {
				itemMap['itemType'] = name;
				items[name] = decode(itemMap, Item);
			});
		});

		Log.verbose('[Item] Loaded ${items.length} items');
		return items.length;
	}

	// Load consume values from JSON file
	static Future<int> loadConsumeValues() async {
		if (items.length == 0) {
			throw 'You must load items before consume values';
		}

		int total = 0;
		String filePath = path.join(
			serverDir.path, 'lib', 'entities', 'items', 'actions', 'consume.json');
		JSON.decode(await new File(filePath).readAsString()).forEach((String item, Map award) {
			try {
				items[item].consumeValues = award;
				total++;
			} catch (e) {
				Log.error('Error setting consume values for $item to $award', e);
			}
		});

		Log.verbose('[Item] Loaded $total consume values');
		return total;
	}

	// Discounts, stored as itemType: part paid out of 1 (eg. 0.8 for 20% off)
	static Map<String, num> discountedItems = {};

	// Properties

	@Field() String category;
	@Field() String iconUrl;
	@Field() String spriteUrl;
	@Field() String brokenUrl;
	@Field() String toolAnimation;
	@Field() String name;
	@Field() String recipeName;
	@Field() String description;
	@Field() String itemType;
	@Field() String item_id;
	@Field() int price;
	@Field() int stacksTo;
	@Field() int iconNum = 4;
	@Field() int durability;
	@Field() int subSlots = 0;
	@Field() num x, y;
	@Field() bool onGround = false;
	@Field() bool isContainer = false;
	@Field() List<String> subSlotFilter;
	@Field() List<Action> actions = [];
	@Field() Map<String, int> consumeValues = {};
	@Field() Map<String, String> metadata = {};

	Action dropAction = new Action.withName('drop')
		..description = "Drop this item on the ground."
		..multiEnabled = true;

	Action pickupAction = new Action.withName('pickup')
		..description = "Put this item in your bags."
		..multiEnabled = true;

	num get discount => discountedItems[itemType] ?? 1;

	// Constructors

	Item();

	Item.clone(this.itemType) {
		Item model = items[itemType];
		category = model.category;
		iconUrl = model.iconUrl;
		spriteUrl = model.spriteUrl;
		brokenUrl = model.brokenUrl;
		toolAnimation = model.toolAnimation;
		name = model.name;
		recipeName = model.recipeName;
		description = model.description;
		price = model.price;
		stacksTo = model.stacksTo;
		iconNum = model.iconNum;
		durability = model.durability;
		x = model.x;
		y = model.y;
		isContainer = model.isContainer;
		subSlots = model.subSlots;
		subSlotFilter = model.subSlotFilter;
		metadata = model.metadata;
		actions = model.actions;
		consumeValues = model.consumeValues;

		//make sure the drop action is last
		actions.removeWhere((Action action) => action.actionName == 'drop');
		actions.add(dropAction);
	}

	// Exporters

	Map getMap() => {
		"iconUrl": iconUrl,
		"spriteUrl": spriteUrl,
		"brokenUrl": brokenUrl,
		"name": name,
		"recipeName": recipeName,
		"itemType": itemType,
		"category": category,
		"isContainer": isContainer,
		"description": description,
		"price": price,
		"stacksTo": stacksTo,
		"iconNum": iconNum,
		"id": item_id,
		"onGround": onGround,
		"x": x,
		"y": y,
		"actions": actionList,
		"tool_animation": toolAnimation,
		"durability": durability,
		"subSlots": subSlots,
		"metadata": metadata,
		"discount": discount,
		"consumeValues": consumeValues
	};

	@override
	String toString() => "An item of type $itemType with metadata $metadata";

	// Getters

	List<Map> get actionList {
		List<Map> result = [];
		if (onGround) {
			actions.forEach((Action action) {
				if (action.groundAction) {
					result.add(encode(action));
				}
			});
			result.add(encode(pickupAction));
			return result;
		} else {
			//make sure the drop action is last
			actions.removeWhere((Action action) => action.actionName == 'drop');
			List<Map> result = encode(actions);
			result.add(encode(dropAction));
			return result;
		}
	}

	bool filterAllows({Item testItem, String itemType}) {
		// Allow an empty slot
		if (testItem == null && itemType == null) {
			return true;
		}

		if (itemType != null && itemType.isEmpty) {
			// Bags except empty item types (this is an empty slot)
			return true;
		}

		if (testItem == null) {
			testItem = items[itemType];
		}

		if (subSlotFilter.length == 0) {
			return !testItem.isContainer;
		} else {
			return subSlotFilter.contains(testItem.itemType);
		}
	}

	// Generic item actions

	Future<bool> openQuest({String streetName, Map map, WebSocket userSocket, String email, String username}) async {
		InventoryV2 inv = await getInventory(email);
		Item itemInSlot = await inv.getItemInSlot(map['slot'], map['subSlot'], email);
		Quest quest = decode(JSON.decode(itemInSlot.metadata['questData']), Quest);

		// Install the quest in the map of available quests
		quests[quest.id] = quest;
		QuestEndpoint.questLogCache[email].offerQuest(
			quest.id, fromItem: true, slot: map['slot'], subSlot: map['subSlot']
			);

		return true;
	}

	// Client: ground -> inventory
	Future pickup({WebSocket userSocket, String email, String username, int count: 1}) async {
		onGround = false;

		Item item = new Item.clone(itemType)
			..onGround = false
			..metadata = this.metadata;

		await InventoryV2.addItemToUser(email, item.getMap(), count, item_id);
		StatManager.add(email, Stat.items_picked_up, increment: count);
	}

	// Client: inventory -> ground
	Future drop({WebSocket userSocket, Map map, String streetName, String email, String username}) async {
		Item droppedItem = await InventoryV2.takeItemFromUser(
			email, map['slot'], map['subSlot'], map['count']
			);

		Identifier playerId = PlayerUpdateHandler.users[username];

		if (droppedItem == null|| playerId == null) {
			return;
		}

		for (int i = 0; i < map['count']; i++) {
			droppedItem.putItemOnGround(playerId.currentX+40, playerId.currentY, streetName);
		}

		StatManager.add(email, Stat.items_dropped, increment: map['count']);
	}

	// Item -> EntityItem
	Future place({WebSocket userSocket, Map map, String streetName, String email, String username}) async {
		String tsid = MapData.getStreetByName(streetName)['tsid'];
		if (tsid == null) {
			toast('Something went wrong! Try another street?', userSocket);
			Log.warning('Street <label=$streetName> has no TSID');
			return;
		}

		Item placedItem = await InventoryV2.takeItemFromUser(email, map['slot'], map['subSlot'], 1);
		if (placedItem != null) {
			EntityItem.place(email, placedItem.itemType, tsid);
		}
	}

	// Place the item in the street
	void putItemOnGround(num x, num y, String streetName, {String id, int count: 1}) {
		Street street = StreetUpdateHandler.streets[streetName];
		if (street == null) {
			return;
		}

		for (int i=0; i<count; i++) {
			String tempId = id;
			if (tempId == null) {
				String randString = new Random().nextInt(10000).toString();
				tempId = "i" + createId(x, y, itemType, streetName + randString);
			}

			Item item = new Item.clone(itemType)
				..x = x
				..y = y
				..item_id = tempId
				..onGround = true
				..metadata = this.metadata;
			item.y = street.getYFromGround(item.x, item.y, 1, 1);

			street.groundItems[tempId] = item;
		}
	}
}
