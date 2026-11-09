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

# Menyimpan ID ayam spesifik yang sudah ditangkap agar tidak respawn saat pindah scene
var collected_chick_ids: Dictionary = {}


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
		
		# Jika ayam sudah 3/3, ubah status ke READY_TO_SUBMIT (jangan langsung complete_quest!)
		if quests[quest_id]["collected_count"] >= quests[quest_id]["target_count"]:
			quests[quest_id]["status"] = "READY_TO_SUBMIT"
			print("QuestManager: Quest '", quest_id, "' siap diserahkan ke Peternak!")
			quest_status_changed.emit(quest_id, "READY_TO_SUBMIT")


func get_quest_progress(quest_id: String) -> int:
	if quests.has(quest_id) and quests[quest_id].has("collected_count"):
		return quests[quest_id]["collected_count"]
	return 0


# --- FUNGSI KHUSUS UNTUK MENANGKAP ANIMAL/ITEM SECARA PERSISTEN ---
func collect_chick(chick_id: String) -> void:
	if not collected_chick_ids.has(chick_id):
		collected_chick_ids[chick_id] = true
		add_quest_progress("quest_ayam_1", 1)


func is_chick_collected(chick_id: String) -> bool:
	return collected_chick_ids.has(chick_id) and collected_chick_ids[chick_id]
