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
		if key == 'addr:housenumber' and value:
			newtags[key] = value
		elif key == 'addr:street' and value:
			newtags[key] = value
		elif key == 'est_h_feet' and value and value != '0':
			newtags['height'] = value+"'"
		elif key == 'storyabove' and value and value != '0':
			newtags['building:levels'] = value
		elif key == 'storybelow' and value and value != '0':
			newtags['building:levels:underground'] = value
		elif key == 'cwwuse':
			if value and value in cwwuse_map:
				newtags['building'] = cwwuse_map[value]
			else:
				newtags['building'] = 'yes'
	return newtags
