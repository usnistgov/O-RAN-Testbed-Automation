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

print('Selecting Labeled_KPI_Metrics.csv file...')
kpi_metrics_path = selectFile(r'Labeled_KPI_Metrics[_\.]?(.*)\.csv', True)
print('Selected:', kpi_metrics_path)
print()

# First check Labeled_KPI_Metrics file name for date, otherwise, use Jamming_Metrics file name date
append_date = re.search(r'Labeled_KPI_Metrics[_\.]?(.*)\.csv', kpi_metrics_path)
if append_date:
	append_date = append_date.group(1)
else:
	append_date = ''

output_file_name = f'Annotated_KPI_Metrics_{append_date}.csv'
print('Output file name:', output_file_name)

#input('Press Enter to proceed...')

output_file = open(output_file_name, 'w', newline='')
output_writer = csv.writer(output_file)
output_header = 'time_start,time_end,tx_gain,'
output_writer.writerow(output_header.strip(',').split(','))

print('Reading Labeled_KPI_Metrics data...')
jamming_start_timestamp=None
jamming_end_timestamp=None
jamming_tx_gain=None

with open(kpi_metrics_path, 'r') as kpi_file:
	reader = csv.reader(kpi_file)
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
				output_writer.writerow(row_to_write)

				# Clear the jamming info after writing
				jamming_start_timestamp = None
				jamming_end_timestamp = None
				jamming_tx_gain = None

output_file.close()
print('Successfully wrote to', output_file_name)
