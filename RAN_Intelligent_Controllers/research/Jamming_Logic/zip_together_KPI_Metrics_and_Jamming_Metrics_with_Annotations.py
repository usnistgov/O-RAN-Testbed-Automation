import csv
import os
import re
import sys
import math

# Given a regular expression, list the files that match it, and ask for user input to select one or more of them
def selectFile(regex, subdirs=False, multiSelect=False):
	try:
		files = []
		compiledRegex = re.compile(regex)
		if subdirs:
			for dirPath, _, fileNames in os.walk('.'):
				for file in fileNames:
					path = os.path.normpath(os.path.join(dirPath, file))
					if compiledRegex.match(path):
						files.append(path)
		else:
			for file in os.listdir(os.curdir):
				fullPath = os.path.join(os.curdir, file)
				if os.path.isfile(fullPath) and compiledRegex.match(file):
					files.append(file)

		if not files:
			print(f'No files were found that match "{regex}"\n')
			return []
		
		if len(files) == 1:
			return files[0]

		print('List of files:')
		for i, file in enumerate(files):
			print(f'  File {i + 1}  -  {file}')
		print()

		selectionPrompt = 'Please select files (e.g., "1,3-5,9" for "1,3,4,5,9"): ' if multiSelect else 'Please select a file: '
		if multiSelect:
			selectedFiles = []
			while not selectedFiles:
				inputStr = input(selectionPrompt)
				selections = re.split(r',\s*|\s+', inputStr)
				addedIndexes = set()

				for selection in selections:
					if '-' in selection:
						parts = selection.split('-')
						try:
							start = int(parts[0]) - 1
							end = int(parts[1]) - 1
							step = 1 if start <= end else -1
							for index in range(start, end + step, step):
								if 0 <= index < len(files) and index not in addedIndexes:
									selectedFiles.append(files[index])
									addedIndexes.add(index)
						except ValueError:
							pass
					else:
						try:
							index = int(selection) - 1
							if 0 <= index < len(files) and index not in addedIndexes:
								selectedFiles.append(files[index])
								addedIndexes.add(index)
						except ValueError:
							pass

				if not selectedFiles:
					print('Invalid selection, please try again.')

			return selectedFiles
		else:
			while True:
				selection = input(selectionPrompt)
				if '-' in selection:
					print('Range selection is not supported in single select mode.')
					continue
				try:
					selection = int(selection)
					if 1 <= selection <= len(files):
						return files[selection - 1]
				except ValueError:
					print('Invalid selection, please try again.')
	except KeyboardInterrupt:
		print("\nOperation cancelled by user.")
		sys.exit()

# Lists files in a directory matching a given regex, optionally including subdirectories
def listFiles(regex = '.*', directory = '', subdirs = True):
	files = []
	if subdirs:
		for root, _, fileNames in os.walk(directory):
			for fileName in fileNames:
				filePath = os.path.join(root, fileName)
				if re.match(regex, fileName):
					files.append(filePath)
	else:
		path = os.path.abspath(directory)
		files = [os.path.join(path, file) for file in os.listdir(path) 
				 if os.path.isfile(os.path.join(path, file)) and re.match(regex, file)]
	return files

print('Selecting KPI_Metrics.csv file...')
kpi_metrics_path = selectFile(r'KPI_Metrics[_\.]?(.*)\.csv', subdirs=True, multiSelect=False)
print('Selected:', kpi_metrics_path)
print()

print('Selecting Jamming_Metrics file...')
jamming_metrics_path = selectFile(r'Jamming_Metrics_.*\.csv', subdirs=True, multiSelect=False)
print('Selected:', jamming_metrics_path)
print()

# First check KPI_Metrics file name for date, otherwise, use Jamming_Metrics file name date
append_date = re.search(r'KPI_Metrics[_\.]?(.*)\.csv', kpi_metrics_path)
if append_date:
	append_date = append_date.group(1)
else:
	# Extract the date from the Jamming_Metrics file name
	append_date = re.search(r'Jamming_Metrics_(.*)\.csv', jamming_metrics_path)
	if append_date:
		append_date = append_date.group(1)

output_labeled_metrics_name = f'Labeled_KPI_Metrics_{append_date}.csv'
print('Output file name:', output_labeled_metrics_name)

#input('Press Enter to proceed...')

# Save the jamming data to memory
print('Reading Jamming_Metrics data...')
with open(jamming_metrics_path, 'r') as jamming_file:
	jamming_reader = csv.reader(jamming_file)
	next(jamming_reader, None)
	jamming_data = list(jamming_reader)

output_labeled_metrics_file = open(output_labeled_metrics_name, 'w', newline='')
output_labeled_metrics_writer = csv.writer(output_labeled_metrics_file)

print('Reading KPI_Metrics data...')
with open(kpi_metrics_path, 'r') as kpi_file:
	kpi_reader = csv.reader(kpi_file)

	header = next(kpi_reader, None)
	if not header:
		print('KPI_Metrics file is empty or has no header.')
		sys.exit(1)
	header.insert(1, 'Is Jamming')
	header.insert(2, 'Jammer TX Gain')
	output_labeled_metrics_writer.writerow(header)

	for i, row in enumerate(kpi_reader, start=1):
		timestamp = float(row[0]) / 1000
		for j, jammer_row in enumerate(jamming_data, start=1):
			jammer_timestamp = float(jammer_row[0])
			jammer_is_jamming = jammer_row[1]
			jammer_tx_gain = jammer_row[2]
			# For each KPI metric, assign the jammer state only if the KPI timestamp is between two jammer timestamps
			if j == 1 and timestamp < float(jammer_row[0]):
				# Before the first jammer timestamp
				row.insert(1, '')
				row.insert(2, '')
				break
			elif j < len(jamming_data):
				next_jammer_row = jamming_data[j]
				lower_time = float(jammer_row[0])
				upper_time = float(next_jammer_row[0])
				if lower_time <= timestamp < upper_time:
					row.insert(1, jammer_row[1])
					row.insert(2, jammer_row[2])
					break
			elif j == len(jamming_data):
				# After the last jammer timestamp
				last_jammer_time = float(jammer_row[0])
				last_jammer_is_jamming = jammer_row[1]
				last_jammer_duration = float(jammer_row[3])
				time_since_last = timestamp - last_jammer_time

				if last_jammer_is_jamming == '1' and time_since_last <= last_jammer_duration:
					# It may have been jamming, but we don't know its duration
					probability_jamming = 1 - (time_since_last / last_jammer_duration)
					row.insert(1, str(probability_jamming))
					row.insert(2, jammer_row[2])
				else:
					row.insert(1, '')
					row.insert(2, '')
				break
		output_labeled_metrics_writer.writerow(row)

output_labeled_metrics_file.close()

#input('Press Enter to proceed to annotations generation...')

print()
print('Generating Annotation_KPI_Metrics file from Labeled_KPI_Metrics file...')

output_annotations_name = 'Annotation_' + output_labeled_metrics_name
print('Output file name:', output_annotations_name)


output_annotations_file = open(output_annotations_name, 'w', newline='')
output_annotations_writer = csv.writer(output_annotations_file)
output_annotations_header = 'time_start,time_end,tx_gain,'
output_annotations_writer.writerow(output_annotations_header.strip(',').split(','))

print('Reading Labeled_KPI_Metrics data...')
jamming_start_timestamp=None
jamming_end_timestamp=None
jamming_tx_gain=None

with open(output_labeled_metrics_name, 'r') as labeled_metrics_file:
	reader = csv.reader(labeled_metrics_file)
	header = next(reader)

	tx_gain = None
	prev_tx_gain = None
	for i, row in enumerate(reader, start=1):
		timestamp = row[0]
		prev_tx_gain = tx_gain
		tx_gain = row[2]
		if prev_tx_gain is None:
			prev_tx_gain = tx_gain

		if tx_gain != prev_tx_gain:
			if tx_gain != '0':
				jamming_start_timestamp = timestamp
				jamming_tx_gain = tx_gain
				jamming_end_timestamp = None
			else:
				jamming_end_timestamp = timestamp
				row_to_write = [jamming_start_timestamp, jamming_end_timestamp, jamming_tx_gain]
				output_annotations_writer.writerow(row_to_write)

				# Clear the jamming info after writing
				jamming_start_timestamp = None
				jamming_end_timestamp = None
				jamming_tx_gain = None

output_annotations_file.close()

print()
print('Successfully zipped KPI_Metrics and Jamming_Metrics data into:', output_labeled_metrics_name)
print('Successfully created annotations file', output_annotations_name)
