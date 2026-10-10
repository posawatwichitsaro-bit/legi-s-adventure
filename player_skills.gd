extends RefCounted

const D = preload("res://data.gd")

static func definition(id: String) -> Dictionary:
	for skill in D.SKILLS:
		if skill.id == id:return skill
	return {}

static func compatible(g, skill: Dictionary) -> bool:
	if not g.ClassProgression.class_id(g) in skill.classes:return false
	if not skill.weapons.is_empty() and not g.primary_weapon() in skill.weapons:return false
	return str(skill.element).is_empty() or str(skill.element) == g.selected_option

static func active_rank(g, effect: String) -> int:
	var result = 0
	for id in g.learned_skills:
		var skill = definition(str(id))
		if not skill.is_empty() and skill.effect == effect and compatible(g,skill):
			result = maxi(result,int(skill.tier))
	return result

static func available(g) -> Array:
	if g.skill_choices_taken >= 5:return []
	return D.SKILLS.filter(func(skill):
		return not skill.id in g.learned_skills and compatible(g,skill) and (skill.requires.is_empty() or skill.requires in g.learned_skills)
	)

static func learn(g, id: String) -> bool:
	var skill = definition(id)
	if skill.is_empty() or not skill in available(g):return false
	g.learned_skills.append(id)
	g.skill_choices_taken += 1
	g.ClassProgression.on_skill(g,skill.effect)
	return true

static func shuffle(g, choices: Array):
	for i in range(choices.size()-1,0,-1):
		var j=g.rng.randi_range(0,i)
		var item=choices[i];choices[i]=choices[j];choices[j]=item

static func offer(g):
	var choices=available(g)
	if choices.is_empty():
		g.skill_reward_taken=true
		g.state="playing"
		return
	shuffle(g,choices)
	g.state="skill"
	var box=g.modal("CHOOSE YOUR SKILL","Boss victory · %s · Skill choice %d / 5\nHigher steps replace earlier effects. Weapon-specific Skills can become dormant." % [D.CLASSES[g.selected_class].name,g.skill_choices_taken+1])
	for i in range(mini(3,choices.size())):
		var skill=choices[i]
		g.button(box,skill.name+"\n"+skill.description,func():
			if not learn(g,skill.id):return
			g.skill_reward_taken=true;g.clear_panel();g.state="playing"
		,Color("514169")).custom_minimum_size.y=85
