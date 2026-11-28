extends Node

# Flag status cutscene dunia
var cutscene_world_2_done: bool = false
var cutscene_world_3_done: bool = false
# Kamu bisa menambah variabel global lain di sini ke depannya:
# var player_max_health: int = 100
# Di GameState.gd
var npc_cina_cutscene_triggered: bool = false

# Status Quest Agroforestri Vietnam (World 4 & World 5)
var vietnam_quest_started: bool = false
var vietnam_clue_tree_found: bool = false     # Petunjuk 1: Pohon besar (World 4)
var vietnam_has_garden_fork: bool = false     # Item: Garpu taman (World 4)
var vietnam_clue_leaves_found: bool = false   # Petunjuk 2: Daun kering (World 5)
var vietnam_quest_completed: bool = false

# Status Quest Penginapan Thailand (0 = belum mulai, 1 = jalan tahap 1, 2 = lapor tahap 1, 3 = jalan tahap 2, 4 = lapor tahap 2, 5 = selesai)
var hotel_quest_stage: int = 0
var hotel_cleaned_objects: Array[String] = [] # Menyimpan ID unik objek kotor yang sudah dibersihkan
