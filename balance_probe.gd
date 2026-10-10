extends "res://main.gd"
# Read-only combat instrumentation for the optional benchmark. No damage,
# healing, timing, or movement rules are changed; this scene never saves.
var measured_damage_taken = 0.0
var measured_hits = 0
func damage_player(amount: float):
	var before = hp
	super.damage_player(amount)
	if hp < before:
		measured_damage_taken += maxf(0,before) - maxf(0,hp)
		measured_hits += 1
var measured_boss_starts: Dictionary = {}
var measured_boss_releases: Dictionary = {}
func update_enemy(enemy: Dictionary, dt: float):
	var before = enemy.get("attack_state","idle")
	super.update_enemy(enemy,dt)
	if enemy.kind != "boss":return
	var after = enemy.get("attack_state","idle")
	var key = enemy.get("attack_pattern","")
	if before != "windup" and after == "windup":
		measured_boss_starts[key] = measured_boss_starts.get(key,0)+1
	if before == "windup" and after == "active":
		measured_boss_releases[key] = measured_boss_releases.get(key,0)+1
