extends Node

signal quest_status_changed(quest_id: String, new_status: String)

var quests: Dictionary = {
	"quest_ayam_1": {
		"title": "Mencari Anak Ayam",
		"status": "NOT_STARTED",
		"collected_count": 0,
		"target_count": 3,
		"require_submit": false,
	},
	"quest_ayam_3": {
		"title": "Ayam Jago Galak",
		"status": "NOT_STARTED",
		"collected_count": 0,
		"target_count": 1,
		"require_submit": true,
	},
	"quest_kopi_1": {
		"title": "Mencari Petunjuk Kebun",
		"status": "NOT_STARTED",
		"collected_count": 0,
		"target_count": 2,
		"require_submit": true,
	}
}

# Menyimpan ID ayam spesifik yang sudah ditangkap agar tidak respawn saat pindah scene
var collected_chick_ids: Dictionary = {}
var chick_complete_dialogue_shown: bool = false

func get_quest_status(quest_id: String) -> String:
	if quests.has(quest_id):
		return quests[quest_id]["status"]
	return "NOT_STARTED"

func start_quest(quest_id: String) -> void:
	if quests.has(quest_id):
		quests[quest_id]["status"] = "ACTIVE"
		print("QuestManager: Quest '", quest_id, "' dimulai!")
		quest_status_changed.emit(quest_id, "ACTIVE")

func complete_quest(quest_id: String, submitted_to_npc: bool = false) -> void:
	if not quests.has(quest_id):
		return

	# Jika quest wajib lapor ke NPC tapi belum diserahkan ke NPC, arahkan ke READY_TO_SUBMIT dulu
	if quests[quest_id].get("require_submit", false) and not submitted_to_npc:
		quests[quest_id]["collected_count"] = quests[quest_id].get("target_count", 1)
		quests[quest_id]["status"] = "READY_TO_SUBMIT"
		print("QuestManager: Quest '", quest_id, "' siap diserahkan ke NPC!")
		quest_status_changed.emit(quest_id, "READY_TO_SUBMIT")
		return

	quests[quest_id]["status"] = "COMPLETED"
	print("QuestManager: Quest '", quest_id, "' SELESAI!")
	quest_status_changed.emit(quest_id, "COMPLETED")

func add_quest_progress(quest_id: String, amount: int = 1) -> void:
	if quests.has(quest_id):
		if not quests[quest_id].has("collected_count"):
			quests[quest_id]["collected_count"] = 0
		quests[quest_id]["collected_count"] += amount
		print("QuestManager: Progress '", quest_id, "' sekarang = ", quests[quest_id]["collected_count"])

		# Jika target tercapai, ubah status ke READY_TO_SUBMIT (jangan langsung complete quest!)
		if quests[quest_id]["collected_count"] >= quests[quest_id].get("target_count", 1):
			quests[quest_id]["status"] = "READY_TO_SUBMIT"
			print("QuestManager: Quest '", quest_id, "' siap diserahkan ke NPC!")
			quest_status_changed.emit(quest_id, "READY_TO_SUBMIT")

			# Munculkan dialog MC otomatis saat semua anak ayam (3/3) ditemukan
			if quest_id == "quest_ayam_1" and not chick_complete_dialogue_shown:
				chick_complete_dialogue_shown = true
				await get_tree().create_timer(0.3).timeout
				if DialogueManager:
					DialogueManager.start_dialogue([
						{"speaker": "mc", "text": "Aku sudah menemukan semuanya!"},
						{"speaker": "mc", "text": "Saatnya kembali ke Paman."}
					])
		else:
			# Tetap emit sinyal ACTIVE agar UI pop-up ter-update menjadi 1/3, 2/3
			quest_status_changed.emit(quest_id, quests[quest_id]["status"])

		# Jika target tercapai, ubah status ke READY_TO_SUBMIT (jangan langsung complete_quest!)
		if quests[quest_id]["collected_count"] >= quests[quest_id]["target_count"]:
			quests[quest_id]["status"] = "READY_TO_SUBMIT"
			print("QuestManager: Quest '", quest_id, "' siap diserahkan ke NPC!")
			quest_status_changed.emit(quest_id, "READY_TO_SUBMIT")
		else:
			# Tetap emit sinyal ACTIVE agar UI pop-up ter-update menjadi 1/2
			quest_status_changed.emit(quest_id, quests[quest_id]["status"])

# Alias agar pemanggilan add_progress() tetap berfungsi
func add_progress(quest_id: String, amount: int = 1) -> void:
	add_quest_progress(quest_id, amount)

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
