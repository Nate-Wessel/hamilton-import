cwwuse_map = {
	'APART': 'apartments',
	'INDUST':'industrial',
	'MNFTRG':'industrial',
	'MLTFM': 'residential',
	'RESDNT':'residential',
	'SCHOOL':'school',
	'GENBUS':'commercial'
}

def filterTags(tags):
	if tags is None:
		return
	newtags = {}
	for (key, value) in tags.items():
		if key == 'addr_house' and value:
			newtags['addr:housenumber'] = value
		elif key == 'addr_stree' and value:
			newtags['addr:street'] = value
		elif key == 'storyabove' and value and value != '0':
			newtags['building:levels'] = value
		elif key == 'cwwuse':
			if value and value in cwwuse_map:
				newtags['building'] = cwwuse_map[value]
			else:
				newtags['building'] = 'yes'
	return newtags
