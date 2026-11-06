extends Node

signal quest_status_changed(quest_id: String, new_status: String)

var quests: Dictionary = {
	"quest_ayam_1": {
		"title": "Mencari Anak Ayam",
		"status": "NOT_STARTED",
		"collected_count": 0,
		"target_count": 3
	},
	"quest_ayam_3": {
		"title": "Ayam Jago Galak",
		"status": "NOT_STARTED",
		"collected_count": 0,
		"target_count": 1
	}
}

func get_quest_status(quest_id: String) -> String:
	if quests.has(quest_id):
		return quests[quest_id]["status"]
	return "NOT_STARTED"

func start_quest(quest_id: String) -> void:
	if quests.has(quest_id):
		quests[quest_id]["status"] = "ACTIVE"
		print("QuestManager: Quest '", quest_id, "' dimulai!")
		quest_status_changed.emit(quest_id, "ACTIVE")

func complete_quest(quest_id: String) -> void:
	if quests.has(quest_id):
		quests[quest_id]["status"] = "COMPLETED"
		print("QuestManager: Quest '", quest_id, "' SELESAI!")
		quest_status_changed.emit(quest_id, "COMPLETED")

func add_quest_progress(quest_id: String, amount: int = 1) -> void:
	if quests.has(quest_id):
		if not quests[quest_id].has("collected_count"):
			quests[quest_id]["collected_count"] = 0
		quests[quest_id]["collected_count"] += amount
		print("QuestManager: Progress '", quest_id, "' sekarang = ", quests[quest_id]["collected_count"])

func get_quest_progress(quest_id: String) -> int:
	if quests.has(quest_id) and quests[quest_id].has("collected_count"):
		return quests[quest_id]["collected_count"]
	return 0
