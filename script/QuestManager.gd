extends Node

# Signal yang dipancarkan saat ada perubahan status quest (Bisa dibaca UI/NPC)
signal quest_status_changed(quest_id, new_status)

# Database Quest dalam bentuk Dictionary
var quests: Dictionary = {
	"collect_wood": {
		"title": "Pengumpul Kayu",
		"status": "NOT_STARTED", # Status: NOT_STARTED, ACTIVE, COMPLETED
		"target_amount": 4
	}
}

# --- FUNGSI UTAMA QUEST ---

# 1. Memulai Quest
func start_quest(quest_id: String) -> void:
	if quests.has(quest_id):
		if quests[quest_id]["status"] == "NOT_STARTED":
			quests[quest_id]["status"] = "ACTIVE"
			quest_status_changed.emit(quest_id, "ACTIVE")
			print("Quest Dimulai: ", quests[quest_id]["title"])

# 2. Menyelesaikan Quest
func complete_quest(quest_id: String) -> void:
	if quests.has(quest_id):
		if quests[quest_id]["status"] == "ACTIVE":
			quests[quest_id]["status"] = "COMPLETED"
			quest_status_changed.emit(quest_id, "COMPLETED")
			print("Quest Selesai: ", quests[quest_id]["title"])

# 3. Mengecek Status Quest (Mengembalikan String: "NOT_STARTED", "ACTIVE", atau "COMPLETED")
func get_quest_status(quest_id: String) -> String:
	if quests.has(quest_id):
		return quests[quest_id]["status"]
	return "NOT_STARTED"

# 4. Mengecek Apakah Quest Sudah Selesai
func is_quest_completed(quest_id: String) -> bool:
	if quests.has(quest_id):
		return quests[quest_id]["status"] == "COMPLETED"
	return false
