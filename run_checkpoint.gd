extends RefCounted

const D = preload("res://data.gd")
const Skills = preload("res://player_skills.gd")

static func read(g) -> Dictionary:
	if not FileAccess.file_exists(g.checkpoint_path):return {}
	var file=FileAccess.open(g.checkpoint_path,FileAccess.READ)
	if file==null:return {}
	var data=JSON.parse_string(file.get_as_text())
	if not data is Dictionary or int(data.get("version",0))!=D.SCHEMA_VERSION:return {}
	for key in ["completed_stage","selected_class","level","xp","hp","kills","elapsed","mastery_bonus_count"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])):return {}
	var cls=int(data.selected_class)
	if cls<0 or cls>=D.CLASSES.size() or int(data.completed_stage)<1 or int(data.completed_stage)>=D.MAX_STAGE:return {}
	if not str(data.get("selected_option","")) in D.CLASSES[cls].options:return {}
	if int(data.level)<1 or int(data.level)>1000 or data.xp<0 or data.xp>=6+int(data.level)*3:return {}
	if data.hp<=0 or data.mastery_bonus_count<0 or data.mastery_bonus_count>200:return {}
	if not data.get("stats") is Dictionary or not data.get("tactic_ranks") is Dictionary or not data.get("learned_skills") is Array or not data.get("equipment") is Array:return {}
	for key in D.STAT_LIMITS:
		if not (data.stats.get(key) is float or data.stats.get(key) is int) or not is_finite(float(data.stats[key])):return {}
	if data.hp>data.stats.max_hp or data.stats.max_hp<=0:return {}
	if data.learned_skills.size()>mini(5,int(data.completed_stage)/5):return {}
	var seen=[]
	for id in data.learned_skills:
		var skill=Skills.definition(str(id))
		if skill.is_empty() or not D.CLASSES[cls].id in skill.classes or id in seen:return {}
		if not skill.requires.is_empty() and not skill.requires in seen:return {}
		seen.append(id)
	for id in data.tactic_ranks:
		var found=false
		for tactic in D.TACTICS:
			if tactic.id==id and (tactic.get("classes",[]).is_empty() or D.CLASSES[cls].id in tactic.classes):
				var value=data.tactic_ranks[id]
				if not (value is int or value is float) or not is_finite(float(value)) or value<0 or value>tactic.cap:return {}
				found=true;break
		if not found:return {}
	for name in data.equipment:
		if not name in D.EQUIPMENT_NAMES:return {}
	for key in ["rng_seed","rng_state"]:
		if not data.get(key) is String or not data[key].is_valid_int():return {}
	return data

static func save(g) -> bool:
	if (g.test_mode and not g.allow_checkpoint_io) or g.stage>=D.MAX_STAGE:return false
	if g.hp<=0 or g.pending_choices>0 or g.remaining_enemies()>0 or not g.gems.is_empty() or not g.potions.is_empty():return false
	if g.stage%5==0 and (not g.skill_reward_taken or not g.boss_reward_taken):return false
	var data={"version":D.SCHEMA_VERSION,"completed_stage":g.stage,"selected_class":g.selected_class,"selected_option":g.selected_option,
		"level":g.level,"xp":g.xp,"hp":g.hp,"stats":g.stats,"kills":g.kills,"elapsed":g.elapsed,
		"tactic_ranks":g.tactic_ranks,"learned_skills":g.learned_skills,"equipment":g.run_equipment,
		"mastery_bonus_count":g.mastery_bonus_count,"rng_seed":str(g.rng.seed),"rng_state":str(g.rng.state)}
	var temp=g.checkpoint_path+".tmp"
	var file=FileAccess.open(temp,FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(data));file.flush();file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(g.checkpoint_path))==OK

static func restore(g) -> bool:
	var data=read(g)
	if data.is_empty():return false
	g.selected_class=int(data.selected_class);g.selected_option=data.selected_option
	g.start_run()
	g.stats=data.stats.duplicate(true);g.mastery_bonus_count=int(data.mastery_bonus_count)
	g.tactic_ranks=data.tactic_ranks.duplicate(true);g.learned_skills=data.learned_skills.duplicate()
	g.skill_choices_taken=g.learned_skills.size()
	g.level=int(data.level);g.xp=float(data.xp);g.hp=float(data.hp)
	g.kills=int(data.kills);g.elapsed=float(data.elapsed);g.run_equipment.assign(data.equipment)
	g.stage=int(data.completed_stage)+1
	g.rng.seed=int(data.rng_seed);g.rng.state=int(data.rng_state)
	g.clamp_stats();g.start_stage()
	g.toast("CONTINUED FROM STAGE %d CHECKPOINT" % int(data.completed_stage))
	return true

static func complete(g):
	if g.test_mode and not g.allow_checkpoint_io:return
	if FileAccess.file_exists(g.checkpoint_path):DirAccess.remove_absolute(ProjectSettings.globalize_path(g.checkpoint_path))
