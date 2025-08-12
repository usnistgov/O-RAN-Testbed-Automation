from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error
from sklearn.preprocessing import MinMaxScaler, StandardScaler
from keras.models import load_model
import argparse
import joblib
import os
import pandas as pd
import re
import sys
import numpy as np

os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'

# Generate bootstrap samples of MSE, MAE, and R2 score for a given model and test data.
def bootstrap_metrics(model, X_test, y_test, num_samples=1000, model_type='default'):
	mse_samples = []
	mae_samples = []
	r2_samples = []
	
	for _ in range(num_samples):
		# Bootstrap sample with replacement
		indices = np.random.choice(range(len(X_test)), len(X_test))
		# If empty, skip
		if len(indices) == 0:
			continue
		if model_type == 'LSTM':
			X_sample = X_test.iloc[indices].to_numpy().reshape(-1, 1, X_test.shape[1])
		else:
			X_sample = X_test.iloc[indices].to_numpy()

		y_sample = y_test.iloc[indices]
		
		# Predict
		predictions = model.predict(X_sample)
		if model_type == 'LSTM':
			predictions = predictions.ravel()  # Flatten predictions for LSTM
		
		# Calculate metrics
		mse_samples.append(mean_squared_error(y_sample, predictions))
		mae_samples.append(mean_absolute_error(y_sample, predictions))
		r2_samples.append(r2_score(y_sample, predictions))
	
	return np.array(mse_samples), np.array(mae_samples), np.array(r2_samples)

# Given a regular expression, list the directories that match it, and ask for user input
def selectDirs(regex, subdirs=False):
	dirs = []
	if subdirs:
		for (dirpath, dirnames, filenames) in os.walk('.'):
			if dirpath[:2] == '.\\' or dirpath[:2] == './':
				dirpath = dirpath[2:]
			if bool(re.match(regex, dirpath)):
				dirs.append(dirpath)
	else:
		for obj in os.listdir(os.curdir):
			if os.path.isdir(obj) and bool(re.match(regex, obj)):
				dirs.append(obj)

	print()
	if len(dirs) == 0:
		print('No directories were found that match', regex)
		print()
		return []

	print('List of directories:')
	for i, directory in enumerate(dirs):
		print(f'  Directory {i + 1}  -  {directory}')
	print()

	selections = []
	while not selections:
		try:
			input_str = input(f'Please select directories (e.g., "1,2,3"): ')
			# Split the input string by any non-digit character and filter out any empty strings from the list
			selected_indices = [int(s)
								for s in re.split(r'\D+', input_str) if s]
			# Convert indices to zero-based and filter out any invalid choices
			selections = [dirs[i - 1]
						  for i in selected_indices if 0 < i <= len(dirs)]
			if not selections:
				raise ValueError()
		except KeyboardInterrupt:
			sys.exit()
		except Exception as e:
			print("Invalid selection. Please try again.")
	print()
	return selections


def main(selected_path=None):
	# fileNameN = ['', 'minmax', 'zscore'].index(normalization)
	# fileNameD = '1' if useDiscretization else '0'
	# fileNameR = str(trainingSplitRatio).replace('.', '_')
	# fileNameC = '1' if trainingSplitChronological else '0'
	# modelPath = f'models_n{fileNameN}_d{fileNameD}_r{fileNameR}_c{fileNameC}_' + os.path.splitext(file_path)[0]
	regex = r'models(?:_ng)?_n([0-9]+)_d([01])_r([0-9\.]+)_c([01]).*'
	# If a path is provided and it is valid, skip selection
	if selected_path and bool(re.match(regex, selected_path)):
		directories = [selected_path]
	else:
		directories = selectDirs(regex, subdirs=True)

	for directory in directories:
		# Configuration
		modelPath = directory
		match = re.match(regex, modelPath)

		if not match or not os.path.exists(modelPath) or not os.path.exists(os.path.join(modelPath, 'X_test.csv')) or not os.path.exists(os.path.join(modelPath, 'y_test.csv')):
			print(f'Directory data not found for {modelPath}, skipping.')
			continue

		non_generalizable = 1 if '_ng' in os.path.basename(modelPath) else 0
		normalization = ['none', 'minmax', 'zscore'][int(match.group(1))]
		useDiscretization = match.group(2) == '1'
		trainingSplitRatio = float(match.group(3))
		trainingSplitChronological = match.group(4) == '1'
	
		results_file_path = os.path.join(modelPath, 'testing_results.csv')

		# Load the test set
		X_test = pd.read_csv(os.path.join(modelPath, 'X_test.csv'))
		y_test = pd.read_csv(os.path.join(modelPath, 'y_test.csv'))

		# Handling missing values in test data
		if X_test.isna().any().any():
			# Replace NaNs with column mean
			X_test.fillna(X_test.mean(), inplace=True)

		if y_test.isna().any().any():
			# Replace NaNs with column mean
			y_test.fillna(y_test.mean(), inplace=True)

		# Discretization
		if useDiscretization:
			y_test = y_test.round().astype(int)  # Round labels to the nearest integer

		# Normalization
		if normalization.lower() == 'minmax':
			# Load the MinMaxScaler used during training
			scaler = joblib.load(os.path.join(modelPath, 'minmax_scaler.pkl'))
			X_test = scaler.transform(X_test)
		elif normalization.lower() == 'zscore':
			# Load the StandardScaler used during training
			scaler = joblib.load(os.path.join(modelPath, 'zscore_scaler.pkl'))
			X_test = scaler.transform(X_test)
		else:
			pass

		# Models to load and evaluate
		model_names = ['LinearRegression', 'RidgeRegression', 'RandomForest', 'GradientBoosting', 'LSTMModel', 'KNearestNeighbors', 'SupportVectorRegression', 'DeepNeuralNetwork']

		# Initialize an empty list to hold evaluation results
		results_list = []

		# Before the loop to evaluate each model, calculate the baseline predictions
		mean_label = y_test.mean().values[0]
		baseline_mean_predictions = np.full_like(y_test, fill_value=mean_label)  # Create an array filled with the mean label
		baseline_mean_mse = mean_squared_error(y_test, baseline_mean_predictions)
		baseline_mean_mae = mean_absolute_error(y_test, baseline_mean_predictions)
		baseline_mean_r2 = r2_score(y_test, baseline_mean_predictions)
		results_list.append({'Model': 'Mean Baseline', 'Mean Squared Error': baseline_mean_mse, 'Mean Absolute Error': baseline_mean_mae, 'R2': baseline_mean_r2})

		fixed_label = 1
		baseline_fixed_predictions = np.full_like(y_test, fill_value=fixed_label)
		baseline_fixed_mse = mean_squared_error(y_test, baseline_fixed_predictions)
		baseline_fixed_mae = mean_absolute_error(y_test, baseline_fixed_predictions)
		baseline_fixed_r2 = r2_score(y_test, baseline_fixed_predictions)
		results_list.append({'Model': 'Fixed Baseline', 'Mean Squared Error': baseline_fixed_mse, 'Mean Absolute Error': baseline_fixed_mae, 'R2': baseline_fixed_r2})

		ideal_predictions = y_test.copy()  # Assuming y_test is a DataFrame with a single target column
		ideal_mse = mean_squared_error(y_test, ideal_predictions)
		ideal_mae = mean_absolute_error(y_test, ideal_predictions)
		ideal_r2 = r2_score(y_test, ideal_predictions)
		results_list.append({'Model': 'Ideal Model', 'Mean Squared Error': ideal_mse, 'Mean Absolute Error': ideal_mae, 'R2': ideal_r2})

		# Evaluate each model and append to list
		for name in model_names:
			if name == 'DeepNeuralNetwork':
				# Regular expression to match DNN model files
				#  model_filename = os.path.join(modelPath, f'DeepNeuralNetwork_n{dnn_neurons}_{dnn_activation}_e{dnn_epochs}_b{dnn_batch_size}_h{dnn_hidden_layers}_model.h5')
				# DeepNeuralNetwork_n64_relu_e1000_b64_h2_model
				# Regular expression to match DNN model files
				dnn_regex = r'DNN_n(\d+)_(\w+)_e(\d+)_b(\d+)_h(\d+)_model\.(h5|keras)'
				# Iterate through the files in the directory
				for file in os.listdir(modelPath):
					match = re.match(dnn_regex, file)
					if match:
						dnn_filename = file
						dnn_neurons, dnn_activation, dnn_epochs, dnn_batch_size, dnn_hidden_layers, _ = match.groups()
						
						# Load the DNN model
						model_filename = os.path.join(modelPath, dnn_filename)
						if os.path.exists(model_filename):
							model = load_model(model_filename)
							
							# Make predictions with the loaded model
							# predictions = model.predict(X_test)
							# Calculate metrics
							# mse = mean_squared_error(y_test, predictions)
							# mae = mean_absolute_error(y_test, predictions)
							# r2 = r2_score(y_test, predictions)
							mse_samples, mae_samples, r2_samples = bootstrap_metrics(model, X_test, y_test, num_samples=1000)
							
							# output = f'\n\n\n{name} ({dnn_filename}) - MSE: {mse:.4f}, MAE: {mae:.4f}, R2 Score: {r2:.4f}\n\n\n'
							# # Print to screen
							# print(output)
							# # Append results to the list
							# results_list.append({
							# 	'Model': f'{name} ({dnn_filename})', 
							# 	'Mean Squared Error': mse, 
							# 	'Mean Absolute Error': mae, 
							# 	'R2': r2
							# })
							for i, (mse, mae, r2) in enumerate(zip(mse_samples, mae_samples, r2_samples)):
								output = f'\n\n\n{name} ({dnn_filename}) - Sample {i+1} - MSE: {mse:.4f}, MAE: {mae:.4f}, R2 Score: {r2:.4f}\n\n\n'
								# Print to screen
								print(output)
								# Append results to the list
								results_list.append({
									'Model': f'{name} ({dnn_filename})', 
									'Mean Squared Error': mse, 
									'Mean Absolute Error': mae, 
									'R2': r2
								})
						else:
							print(f"Model file {model_filename} not found. Skipping {name} ({dnn_filename}).")

			elif name == 'LSTMModel':

				#model_filename = os.path.join(modelPath, f'LSTMModel_e{lstm_epochs}_b{lstm_batch_size}_u{lstm_units}_a{lstm_activation}_ra{lstm_recurrent_activation}_d{lstm_dropout}_rd{lstm_recurrent_dropout}_u{lstm_unroll}_b{lstm_use_bias}_model.keras')
				lstm_regex = r'LSTM_e(\d+)_b(\d+)_u(\d+)_a(\w+)_ra(\w+)_d(\d+\.\d+)_rd(\d+\.\d+)_u(\d+)_b(\d+)_model\.keras'
				fileName = os.path.join(modelPath, 'LSTMModel_model.keras')
				# Iterate through the files in the directory
				for file in os.listdir(modelPath):
					match = re.match(lstm_regex, file)
					if match:
						lstm_filename = file
						lstm_epochs, lstm_batch_size, lstm_units, lstm_activation, lstm_recurrent_activation, lstm_dropout, lstm_recurrent_dropout, lstm_unroll, lstm_use_bias = match.groups()
						
						# Load the LSTM model
						model_filename = os.path.join(modelPath, lstm_filename)
						if os.path.exists(model_filename):
							model = load_model(model_filename)
							
							# Reshape test data
							X_test_reshaped = np.reshape(X_test, (X_test.shape[0], 1, X_test.shape[1]))

							# Make predictions
							# predictions = model.predict(X_test_reshaped)
							# Calculate metrics
							# mse = mean_squared_error(y_test, predictions)
							# mae = mean_absolute_error(y_test, predictions)
							# r2 = r2_score(y_test, predictions)
							mse_samples, mae_samples, r2_samples = bootstrap_metrics(model, X_test, y_test, num_samples=1000, model_type='LSTM')

							# output = f'\n\n\n{name} ({lstm_filename}) - MSE: {mse:.4f}, MAE: {mae:.4f}, R2 Score: {r2:.4f}\n\n\n'
							# # Print to screen
							# print(output)
							# # Append results to the list
							# results_list.append({
							# 	'Model': f'{name} ({lstm_filename})', 
							# 	'Mean Squared Error': mse, 
							# 	'Mean Absolute Error': mae, 
							# 	'R2': r2
							# })
							for i, (mse, mae, r2) in enumerate(zip(mse_samples, mae_samples, r2_samples)):
								output = f'\n\n\n{name} ({lstm_filename}) - Sample {i+1} - MSE: {mse:.4f}, MAE: {mae:.4f}, R2 Score: {r2:.4f}\n\n\n'
								# Print to screen
								print(output)
								# Append results to the list
								results_list.append({
									'Model': f'{name} ({lstm_filename})', 
									'Mean Squared Error': mse, 
									'Mean Absolute Error': mae, 
									'R2': r2
								})
						else:
							print(f"Model file {model_filename} not found. Skipping {name} ({lstm_filename}).")

			else:
				fileName = os.path.join(modelPath, f'{name}_model.pkl')
				if not os.path.exists(fileName): continue
				model = joblib.load(fileName)

				# Make predictions
				# predictions = model.predict(X_test)
				# Calculate metrics and append results
				# mse = mean_squared_error(y_test, predictions)
				# mae = mean_absolute_error(y_test, predictions)
				# r2 = r2_score(y_test, predictions)
				mse_samples, mae_samples, r2_samples = bootstrap_metrics(model, X_test, y_test, num_samples=1000)

				# output = f'\n\n\n{name} - MSE: {mse:.4f}, MAE: {mae:.4f}, R2 Score: {r2:.4f}\n\n\n'
				# # Print to screen
				# print(output)
				# # Append results to the list
				# results_list.append({'Model': name, 'Mean Squared Error': mse, 'Mean Absolute Error': mae, 'R2': r2})
				for i, (mse, mae, r2) in enumerate(zip(mse_samples, mae_samples, r2_samples)):
					output = f'\n\n\n{name} - Sample {i+1} - MSE: {mse:.4f}, MAE: {mae:.4f}, R2 Score: {r2:.4f}\n\n\n'
					# Print to screen
					print(output)
					# Append results to the list
					results_list.append({
						'Model': f'{name}', 
						'Mean Squared Error': mse, 
						'Mean Absolute Error': mae, 
						'R2': r2
					})

		# Create a DataFrame from the list of results
		results_df = pd.DataFrame(results_list)

		# Save the results to a CSV file
		results_df.to_csv(results_file_path, index=False)

if __name__ == '__main__':
	parser = argparse.ArgumentParser(
		description="Evaluate machine learning models.")
	parser.add_argument(
		'-f', '--folder', help='Specify the path of the directory to evaluate.', type=str)
	args = parser.parse_args()
	main(selected_path=args.folder)